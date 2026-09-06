-- str_encrypt.lua: 指令层面的字符串加密和自解密
-- 加密常量池中的字符串，插入解密函数，替换 LOADK 为解密调用

local luac = require('luac')
local junk_jmp = require('junk_jmp')

local str_encrypt = {}

-- 每字符串独立随机 key, key 存在密文第 1 字节
-- 解密函数从密文前缀读 key, 不再硬编码
local function xor_crypt(s)
    local key = math.random(1, 255)
    local bytes = {string.char(key)}
    for i = 1, #s do
        bytes[i + 1] = string.char(string.byte(s, i) ~ key)
    end
    return table.concat(bytes)
end

-- 递归收集所有 proto（避免处理时添加新函数导致无限递归）
local function collect_protos(proto, list)
    list = list or {}
    list[#list + 1] = proto
    if proto.p then
        for i = 1, #proto.p do
            collect_protos(proto.p[i], list)
        end
    end
    return list
end

-- 找出函数中所有引用字符串的 LOADK 指令
local function find_string_loadks(proto)
    local string_set = {}
    local string_indices = {}
    for i = 1, #proto.k do
        if type(proto.k[i]) == 'string' then
            string_set[i - 1] = true  -- 0-based
            string_indices[#string_indices + 1] = i - 1
        end
    end

    local loadks = {}
    for i = 1, #proto.code do
        local op = luac.GET_OPCODE(proto.code[i])
        if op == luac.OP_LOADK then
            local bx = luac.GETARG_Bx(proto.code[i])
            if string_set[bx] then
                loadks[#loadks + 1] = {
                    pos = i,
                    reg = luac.GETARG_A(proto.code[i]),
                    const_idx = bx
                }
            end
        end
    end
    return loadks, string_indices
end

-- 计算函数使用的最大寄存器号
local function calc_max_reg(proto)
    local max_r = proto.maxstacksize - 1
    for i = 1, #proto.code do
        local op = luac.GET_OPCODE(proto.code[i])
        local a = luac.GETARG_A(proto.code[i])
        if a > max_r then max_r = a end
        if op <= 46 then
            local b = luac.GETARG_B(proto.code[i])
            local c = luac.GETARG_C(proto.code[i])
            if b < 255 and b > max_r then max_r = b end
            if c < 255 and c > max_r then max_r = c end
        end
    end
    return math.max(max_r, 0)
end

-- 构造解密函数的 proto
-- 解密逻辑: 第 1 字节是 key, 后续字节逐字节 XOR 还原
-- 生成后对解密函数自身应用指令变异和不透明谓词, 增加识别难度
local function make_decrypt_proto()
    local src = [[
        return function(s)
            local key = s:byte(1)
            local r = ""
            for i = 2, #s do
                r = r .. string.char(string.byte(s, i) ~ key)
            end
            return r
        end
    ]]
    local func = load(src)
    local bc = string.dec(string.dump(func))
    local proto = luac.undump(bc, false)
    -- main 返回一个闭包，子函数就是解密函数
    if proto.p and #proto.p >= 1 then
        local dec = proto.p[1]
        -- 修正 upvalue：从父函数的 upvalue 列表获取第 0 个（_ENV）
        if dec.upvalues and #dec.upvalues > 0 then
            dec.upvalues[1].instack = 0
            dec.upvalues[1].idx = 0
        end
        -- 关键：从临时 main proto 中移除 dec，防止 main 被 GC 时递归释放 dec
        proto.p = {}

        -- 解密函数自混淆: 指令变异 + 不透明谓词
        -- 用 pcall 包裹, 混淆模块异常不影响主流程
        pcall(function()
            local im = require('instruction_mutate')
            im.process_function(dec, {})
        end)
        pcall(function()
            local op = require('opaque_predicate')
            op.process_function(dec, {})
        end)

        return dec
    end
    return nil
end

-- 对单个函数进行字符串加密
function str_encrypt.encrypt_function(proto, options)
    options = options or {}

    local loadks, string_indices = find_string_loadks(proto)
    if #string_indices == 0 then return 0 end

    -- 加密所有字符串常量 (每个独立随机 key, 存在密文前缀)
    for _, idx in ipairs(string_indices) do
        proto.k[idx + 1] = xor_crypt(proto.k[idx + 1])
    end

    -- 构造解密函数并添加到 proto.p
    local dec_proto = make_decrypt_proto()
    local dec_proto_idx = 0
    local dec_maxstack = 12  -- 默认
    if dec_proto then
        proto.p[#proto.p + 1] = dec_proto
        dec_proto_idx = #proto.p - 1  -- 0-based
        dec_maxstack = dec_proto.maxstacksize or 12
    end

    -- 计算寄存器分配
    -- dec_reg 必须放在父函数原始栈顶之后，否则解密函数的栈帧（以及其内部C函数调用的栈帧）
    -- 会覆盖父函数的高寄存器
    local original_maxstack = proto.maxstacksize
    local dec_reg = original_maxstack  -- 函数寄存器放在原始栈顶
    local arg_reg = dec_reg + 1         -- 参数寄存器
    -- 解密函数栈帧从 dec_reg+1 开始，占 dec_maxstack 个寄存器
    -- 内部C函数调用可能再扩展，留额外空间
    local safe_base = dec_reg + dec_maxstack + 16
    local table_reg = safe_base                      -- GETTABUP 临时表寄存器
    local key_reg = safe_base + 1                    -- 临时 key 寄存器
    local val_reg = safe_base + 2                    -- 临时 value 寄存器

    -- 父函数需要足够的栈空间
    local needed_stack = val_reg + 1

    -- 判断 RK 值是否是被加密的字符串常量
    -- RK >= 256 时才是常量引用; 寄存器 (<256) 不可能是加密常量
    local function is_enc_rk(rk)
        if rk < 256 then return false end
        local idx = rk - 256
        for _, i in ipairs(string_indices) do
            if idx == i then return true end
        end
        return false
    end

    -- 发射解密序列：src_reg 中的加密字符串 -> dst_reg
    local function emit_decrypt(code, src_reg, dst_reg)
        table.insert(code, luac.CREATE_ABx(luac.OP_CLOSURE, dec_reg, dec_proto_idx))
        table.insert(code, luac.CREATE_ABC(luac.OP_MOVE, arg_reg, src_reg, 0))
        table.insert(code, luac.CREATE_ABC(luac.OP_CALL, dec_reg, 2, 2))
        table.insert(code, luac.CREATE_ABC(luac.OP_MOVE, dst_reg, dec_reg, 0))
    end

    -- 构建新的指令序列
    local new_code = {}

    -- 复制原始代码，替换字符串 LOADK 和 GETTABUP
    for i = 1, #proto.code do
        local inst = proto.code[i]
        local op = luac.GET_OPCODE(inst)
        if op == luac.OP_LOADK then
            local bx = luac.GETARG_Bx(inst)
            local is_string = false
            for _, idx in ipairs(string_indices) do
                if bx == idx then is_string = true; break end
            end
            if is_string then
                local a = luac.GETARG_A(inst)
                -- 1. LOADK a, bx （加载加密字符串到 a）
                table.insert(new_code, inst)
                -- 2-5. 解密 a -> a
                emit_decrypt(new_code, a, a)
            else
                table.insert(new_code, inst)
            end
        elseif op == luac.OP_GETTABUP then
            local a = luac.GETARG_A(inst)
            local b = luac.GETARG_B(inst)
            local c = luac.GETARG_C(inst)
            if is_enc_rk(c) then
                local kidx = (c >= 256) and (c - 256) or c
                -- GETUPVAL table_reg, b （获取 upvalue 表）
                table.insert(new_code, luac.CREATE_ABC(luac.OP_GETUPVAL, table_reg, b, 0))
                -- LOADK key_reg, kidx （加载加密的 key）
                table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg, kidx))
                -- 解密 key_reg -> key_reg
                emit_decrypt(new_code, key_reg, key_reg)
                -- GETTABLE a, table_reg, key_reg （用解密后的 key 获取值）
                table.insert(new_code, luac.CREATE_ABC(luac.OP_GETTABLE, a, table_reg, key_reg))
            else
                table.insert(new_code, inst)
            end
        elseif op == luac.OP_GETTABLE then
            local a = luac.GETARG_A(inst)
            local b = luac.GETARG_B(inst)
            local c = luac.GETARG_C(inst)
            if is_enc_rk(c) then
                local kidx = c - 256
                -- LOADK key_reg, kidx （加载加密的 key）
                table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg, kidx))
                -- 解密 key_reg -> key_reg
                emit_decrypt(new_code, key_reg, key_reg)
                -- GETTABLE a, b, key_reg （用解密后的 key 获取值，key_reg 是寄存器）
                table.insert(new_code, luac.CREATE_ABC(luac.OP_GETTABLE, a, b, key_reg))
            else
                table.insert(new_code, inst)
            end
        elseif op == luac.OP_SELF then
            -- SELF A B C: R(A+1)=R(B), R(A)=R(B)[R(C)]
            -- C 是 RK, 可能是加密的字符串键
            local a = luac.GETARG_A(inst)
            local b = luac.GETARG_B(inst)
            local c = luac.GETARG_C(inst)
            if is_enc_rk(c) then
                local kidx = c - 256
                -- 先解密键到 key_reg, 再用寄存器键执行 SELF
                table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg, kidx))
                emit_decrypt(new_code, key_reg, key_reg)
                table.insert(new_code, luac.CREATE_ABC(luac.OP_SELF, a, b, key_reg))
            else
                table.insert(new_code, inst)
            end
        elseif op == luac.OP_SETTABUP then
            local a = luac.GETARG_A(inst)  -- upvalue index
            local b = luac.GETARG_B(inst)  -- key (RKB)
            local c = luac.GETARG_C(inst)  -- value (RKC)
            local key_enc = is_enc_rk(b)
            local val_enc = is_enc_rk(c)
            if key_enc or val_enc then
                -- GETUPVAL table_reg, a
                table.insert(new_code, luac.CREATE_ABC(luac.OP_GETUPVAL, table_reg, a, 0))
                -- 处理 key
                if key_enc then
                    local kidx = b - 256
                    table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg, kidx))
                    emit_decrypt(new_code, key_reg, key_reg)
                else
                    -- key 是寄存器或明文，直接 MOVE 到 key_reg
                    if b >= 256 then
                        table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg, b - 256))
                    else
                        table.insert(new_code, luac.CREATE_ABC(luac.OP_MOVE, key_reg, b, 0))
                    end
                end
                -- 处理 value
                if val_enc then
                    local vidx = c - 256
                    table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, val_reg, vidx))
                    emit_decrypt(new_code, val_reg, val_reg)
                else
                    if c >= 256 then
                        table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, val_reg, c - 256))
                    else
                        table.insert(new_code, luac.CREATE_ABC(luac.OP_MOVE, val_reg, c, 0))
                    end
                end
                -- SETTABLE table_reg, key_reg, val_reg
                table.insert(new_code, luac.CREATE_ABC(luac.OP_SETTABLE, table_reg, key_reg, val_reg))
            else
                table.insert(new_code, inst)
            end
        elseif op == luac.OP_SETTABLE then
            local a = luac.GETARG_A(inst)  -- table
            local b = luac.GETARG_B(inst)  -- key (RKB)
            local c = luac.GETARG_C(inst)  -- value (RKC)
            local key_enc = is_enc_rk(b)
            local val_enc = is_enc_rk(c)
            if key_enc or val_enc then
                -- 处理 key
                if key_enc then
                    local kidx = b - 256
                    table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg, kidx))
                    emit_decrypt(new_code, key_reg, key_reg)
                else
                    if b >= 256 then
                        table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg, b - 256))
                    else
                        table.insert(new_code, luac.CREATE_ABC(luac.OP_MOVE, key_reg, b, 0))
                    end
                end
                -- 处理 value
                if val_enc then
                    local vidx = c - 256
                    table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, val_reg, vidx))
                    emit_decrypt(new_code, val_reg, val_reg)
                else
                    if c >= 256 then
                        table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, val_reg, c - 256))
                    else
                        table.insert(new_code, luac.CREATE_ABC(luac.OP_MOVE, val_reg, c, 0))
                    end
                end
                -- SETTABLE a, key_reg, val_reg
                table.insert(new_code, luac.CREATE_ABC(luac.OP_SETTABLE, a, key_reg, val_reg))
            else
                table.insert(new_code, inst)
            end
        else
            table.insert(new_code, inst)
        end
    end

    -- 调整所有 JMP 跳转
    if junk_jmp and junk_jmp.adjust_jumps then
        junk_jmp.adjust_jumps(new_code, 1, #new_code)
    end

    proto.code = new_code
    -- 同步 lineinfo 长度，使其和 code 匹配（新增指令行号用 0 填充）
    if proto.lineinfo then
        local new_lineinfo = {}
        for i = 1, #new_code do
            new_lineinfo[i] = proto.lineinfo[i] or 0
        end
        proto.lineinfo = new_lineinfo
    end
    -- 更新 maxstacksize
    proto.maxstacksize = math.min(math.max(proto.maxstacksize, needed_stack, dec_reg + 6), 250)

    return #loadks
end

-- 对整个 proto 树进行字符串加密
function str_encrypt.encrypt(proto, options)
    options = options or {}
    local all_protos = collect_protos(proto)
    local total = 0
    for _, p in ipairs(all_protos) do
        total = total + str_encrypt.encrypt_function(p, options)
    end
    return total
end

return str_encrypt
