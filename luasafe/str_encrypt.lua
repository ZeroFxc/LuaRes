-- str_encrypt.lua: 指令层面的字符串加密和自解密
-- 加密常量池中的字符串，插入解密函数，替换 LOADK 为解密调用

local luac = require('luac')
local junk_jmp = require('junk_jmp')

local str_encrypt = {}

-- XOR 加密/解密
local function xor_crypt(s, key)
    key = key or 0x55
    local bytes = {}
    for i = 1, #s do
        bytes[i] = string.char(string.byte(s, i) ~ key)
    end
    return table.concat(bytes)
end

-- andlua 内置字符串解密（和 lundump.c 的 decrypt_string 一致）
local function andlua_decrypt_string(s)
    local len = #s
    if len == 0 then return s end
    local bytes = {string.byte(s, 1, len)}
    local first = bytes[1] ~ (len % 255)
    bytes[1] = first
    local step = first + len
    local length = len
    for i = 2, len do
        length = length + step
        bytes[i] = bytes[i] ~ (length % 255)
    end
    return string.char(table.unpack(bytes))
end

-- 检查是否是有效文本（简单版：没有 0 字节，主要是可打印 ASCII）
local function is_valid_text(s)
    for i = 1, #s do
        local b = string.byte(s, i)
        if b == 0 then return false end
        if b < 0x20 and b ~= 0x09 and b ~= 0x0A and b ~= 0x0D then return false end
        if b == 0x7F then return false end
    end
    return true
end

-- 确保字符串是明文：如果是 andlua 加密的，先解密
local function ensure_plaintext(s)
    if #s == 0 then return s end
    local decrypted = andlua_decrypt_string(s)
    if is_valid_text(decrypted) then
        return decrypted
    end
    return s  -- 已经是明文
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
local function make_decrypt_proto(key)
    key = key or 0x55
    local src = string.format([[
        return function(s)
            local r = ""
            for i = 1, #s do
                r = r .. string.char(string.byte(s, i) ~ %d)
            end
            return r
        end
    ]], key)
    local func = load(src)
    local bc = string.dec(string.dump(func))
    local proto = luac.undump(bc, false)
    -- main 返回一个闭包，子函数就是解密函数
    if proto.p and #proto.p >= 1 then
        local dec = proto.p[1]
        -- 修正 upvalue：从父函数的 upvalue 列表获取第 0 个（_ENV）
        -- 原来是 instack=1（从父栈获取），改为 instack=0（从父 upvalue 获取）
        if dec.upvalues and #dec.upvalues > 0 then
            dec.upvalues[1].instack = 0
            dec.upvalues[1].idx = 0
        end
        return dec
    end
    return nil
end

-- 对单个函数进行字符串加密
function str_encrypt.encrypt_function(proto, options)
    options = options or {}
    local key = options.key or 0x55

    local loadks, string_indices = find_string_loadks(proto)
    if #string_indices == 0 then return 0 end

    -- 先确保所有字符串是明文（解密 andlua 内置加密）
    for _, idx in ipairs(string_indices) do
        proto.k[idx + 1] = ensure_plaintext(proto.k[idx + 1])
    end

    -- 加密所有字符串常量
    for _, idx in ipairs(string_indices) do
        proto.k[idx + 1] = xor_crypt(proto.k[idx + 1], key)
    end

    -- 计算寄存器分配（用足够高的寄存器避免冲突）
    local max_reg = calc_max_reg(proto)
    local func_save = math.min(max_reg + 10, 240)  -- 保存解密函数的安全寄存器
    local dec_reg = func_save + 1                       -- CALL 用的函数寄存器
    local arg_reg = dec_reg + 1                          -- 参数寄存器
    -- ret_reg = dec_reg (CALL 返回值存到 dec_reg)

    -- 构造解密函数并添加到 proto.p
    local dec_proto = make_decrypt_proto(key)
    local dec_proto_idx = 0
    if dec_proto then
        proto.p[#proto.p + 1] = dec_proto
        dec_proto_idx = #proto.p - 1  -- 0-based
    end

    -- 构建新的指令序列
    local new_code = {}

    -- 开头插入：CLOSURE func_save, dec_proto_idx （解密函数保存到安全寄存器）
    table.insert(new_code, luac.CREATE_ABx(luac.OP_CLOSURE, func_save, dec_proto_idx))

    -- 复制原始代码，替换字符串 LOADK
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
                -- 2. MOVE dec_reg, func_save （把解密函数移到 CALL 寄存器）
                table.insert(new_code, luac.CREATE_ABC(luac.OP_MOVE, dec_reg, func_save, 0))
                -- 3. MOVE arg_reg, a （参数放到 arg_reg）
                table.insert(new_code, luac.CREATE_ABC(luac.OP_MOVE, arg_reg, a, 0))
                -- 4. CALL dec_reg, 2, 2 （调用解密函数，1个参数，1个返回值到 dec_reg）
                table.insert(new_code, luac.CREATE_ABC(luac.OP_CALL, dec_reg, 2, 2))
                -- 5. MOVE a, dec_reg （把结果移回 a）
                table.insert(new_code, luac.CREATE_ABC(luac.OP_MOVE, a, dec_reg, 0))
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
    -- 更新 maxstacksize
    proto.maxstacksize = math.min(math.max(proto.maxstacksize, arg_reg + 1), 250)

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
