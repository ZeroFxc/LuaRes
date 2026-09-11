-- str_encrypt.lua: 纯 opcode 内联字符串加密（v2，零 CALL 零 lua 函数依赖）
-- 加密字符串为 XOR 字节整数数组，每个解密点内联重建 byte->char 表并解密。
-- 不创建解密子函数，不调用 string.char/string.byte，不依赖任何全局。
-- 处理: LOADK, GETTABUP, GETTABLE, SELF, SETTABUP, SETTABLE

local luac = require('luac')
local junk_jmp = require('junk_jmp')

local str_encrypt = {}

local BITRK = 0x100
local OP_MOVE = 0
local OP_LOADK = 1
local OP_GETUPVAL = 5
local OP_GETTABUP = 6
local OP_GETTABLE = 7
local OP_SETTABUP = 8
local OP_SETTABLE = 10
local OP_NEWTABLE = 11
local OP_SELF = 12
local OP_BXOR = 22
local OP_CONCAT = 29

-- 递归收集所有 proto
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

-- 对单个函数进行字符串加密
function str_encrypt.encrypt_function(proto, options)
    options = options or {}

    -- 1. 找出所有字符串常量
    local string_indices = {}
    for i = 1, #proto.k do
        if type(proto.k[i]) == 'string' then
            string_indices[#string_indices + 1] = i - 1  -- 0-based
        end
    end
    if #string_indices == 0 then return 0 end

    -- 快速查找: 某个常量索引是否是加密字符串
    local is_enc = {}
    for _, idx in ipairs(string_indices) do is_enc[idx] = true end

    local function is_enc_rk(rk)
        if rk < BITRK then return false end
        return is_enc[rk - BITRK] ~= nil
    end

    -- 2. 加密每个字符串，收集密钥和密文字节常量索引
    -- enc_info[idx] = { key_kidx, byte_kidx={...}, nbytes }
    local enc_info = {}
    local unique_plain = {}  -- 用到的明文字节集合
    local seen_plain = {}

    for _, idx in ipairs(string_indices) do
        local s = proto.k[idx + 1]
        local key = math.random(1, 255)
        local key_kidx = #proto.k
        table.insert(proto.k, key)

        local byte_kidx = {}
        for j = 1, #s do
            local plain = string.byte(s, j)
            local eb = plain ~ key
            byte_kidx[#byte_kidx + 1] = #proto.k
            table.insert(proto.k, eb)
            if not seen_plain[plain] then
                seen_plain[plain] = true
                unique_plain[#unique_plain + 1] = plain
            end
        end

        enc_info[idx] = {
            key_kidx = key_kidx,
            byte_kidx = byte_kidx,
            nbytes = #s,
        }
    end

    -- 3. 为每个唯一明文字节添加: 整数常量(键) 和 单字符字符串常量(值)
    local byte_key_idx = {}  -- byte -> integer constant index
    local byte_char_idx = {}  -- byte -> 1-char string constant index
    for _, b in ipairs(unique_plain) do
        byte_key_idx[b] = #proto.k
        table.insert(proto.k, b)
        byte_char_idx[b] = #proto.k
        table.insert(proto.k, string.char(b))
    end

    -- 4. 添加空字符串常量
    local empty_kidx = #proto.k
    table.insert(proto.k, "")

    -- 5. 将原始字符串常量置 nil
    for _, idx in ipairs(string_indices) do
        proto.k[idx + 1] = nil
    end

    -- 6. 寄存器分配
    local base = proto.maxstacksize
    local b2c_reg = base
    local key_reg = base + 1
    local tmp_reg = base + 2
    local concat_reg = base + 3
    -- concat_reg+1 (base+4) 用作 CONCAT 的第二操作数
    local res1_reg = base + 5
    local res2_reg = base + 6
    local table_reg = base + 7
    local needed_stack = base + 8

    -- 7. 发射内联解密序列到 result_reg
    local function emit_decrypt(code, enc, result_reg)
        -- 建 byte->char 表
        table.insert(code, luac.CREATE_ABC(OP_NEWTABLE, b2c_reg, 0, #unique_plain))
        for _, b in ipairs(unique_plain) do
            table.insert(code, luac.CREATE_ABC(OP_SETTABLE, b2c_reg,
                byte_key_idx[b] + BITRK, byte_char_idx[b] + BITRK))
        end
        -- 加载密钥和空串
        table.insert(code, luac.CREATE_ABx(OP_LOADK, key_reg, enc.key_kidx))
        table.insert(code, luac.CREATE_ABx(OP_LOADK, concat_reg, empty_kidx))
        -- 逐字节解密
        for i = 1, enc.nbytes do
            table.insert(code, luac.CREATE_ABx(OP_LOADK, tmp_reg, enc.byte_kidx[i]))
            table.insert(code, luac.CREATE_ABC(OP_BXOR, tmp_reg, tmp_reg, key_reg))
            table.insert(code, luac.CREATE_ABC(OP_GETTABLE, tmp_reg, b2c_reg, tmp_reg))
            table.insert(code, luac.CREATE_ABC(OP_MOVE, concat_reg + 1, tmp_reg, 0))
            table.insert(code, luac.CREATE_ABC(OP_CONCAT, concat_reg, concat_reg, concat_reg + 1))
        end
        if result_reg ~= concat_reg then
            table.insert(code, luac.CREATE_ABC(OP_MOVE, result_reg, concat_reg, 0))
        end
    end

    -- 8. 构建新指令序列
    local new_code = {}
    local insert_pos = {}  -- 每条原始指令前已插入的指令数
    local insert_len = {}  -- 每条原始指令对应的插入长度
    local inserted_so_far = 0
    local count = 0

    for i = 1, #proto.code do
        insert_pos[i] = inserted_so_far
        local start_len = #new_code
        local ins = proto.code[i]
        local op = luac.GET_OPCODE(ins)
        local a = luac.GETARG_A(ins)
        local b = luac.GETARG_B(ins)
        local c = luac.GETARG_C(ins)

        if op == OP_LOADK then
            local bx = luac.GETARG_Bx(ins)
            if is_enc[bx] then
                emit_decrypt(new_code, enc_info[bx], a)
                count = count + 1
            else
                table.insert(new_code, ins)
            end
        elseif op == OP_GETTABUP and is_enc_rk(c) then
            local cidx = c - BITRK
            table.insert(new_code, luac.CREATE_ABC(OP_GETUPVAL, table_reg, b, 0))
            emit_decrypt(new_code, enc_info[cidx], res1_reg)
            table.insert(new_code, luac.CREATE_ABC(OP_GETTABLE, a, table_reg, res1_reg))
            count = count + 1
        elseif op == OP_GETTABLE and is_enc_rk(c) then
            local cidx = c - BITRK
            emit_decrypt(new_code, enc_info[cidx], res1_reg)
            table.insert(new_code, luac.CREATE_ABC(OP_GETTABLE, a, b, res1_reg))
            count = count + 1
        elseif op == OP_SELF and is_enc_rk(c) then
            local cidx = c - BITRK
            emit_decrypt(new_code, enc_info[cidx], res1_reg)
            table.insert(new_code, luac.CREATE_ABC(OP_SELF, a, b, res1_reg))
            count = count + 1
        elseif op == OP_SETTABUP then
            local key_enc = is_enc_rk(b)
            local val_enc = is_enc_rk(c)
            if key_enc or val_enc then
                table.insert(new_code, luac.CREATE_ABC(OP_GETUPVAL, table_reg, a, 0))
                if val_enc then
                    emit_decrypt(new_code, enc_info[c - BITRK], res1_reg)
                elseif c >= BITRK then
                    table.insert(new_code, luac.CREATE_ABx(OP_LOADK, res1_reg, c - BITRK))
                else
                    table.insert(new_code, luac.CREATE_ABC(OP_MOVE, res1_reg, c, 0))
                end
                if key_enc then
                    emit_decrypt(new_code, enc_info[b - BITRK], res2_reg)
                elseif b >= BITRK then
                    table.insert(new_code, luac.CREATE_ABx(OP_LOADK, res2_reg, b - BITRK))
                else
                    table.insert(new_code, luac.CREATE_ABC(OP_MOVE, res2_reg, b, 0))
                end
                table.insert(new_code, luac.CREATE_ABC(OP_SETTABLE, table_reg, res2_reg, res1_reg))
                count = count + 1
            else
                table.insert(new_code, ins)
            end
        elseif op == OP_SETTABLE then
            local key_enc = is_enc_rk(b)
            local val_enc = is_enc_rk(c)
            if key_enc or val_enc then
                if val_enc then
                    emit_decrypt(new_code, enc_info[c - BITRK], res1_reg)
                elseif c >= BITRK then
                    table.insert(new_code, luac.CREATE_ABx(OP_LOADK, res1_reg, c - BITRK))
                else
                    table.insert(new_code, luac.CREATE_ABC(OP_MOVE, res1_reg, c, 0))
                end
                if key_enc then
                    emit_decrypt(new_code, enc_info[b - BITRK], res2_reg)
                elseif b >= BITRK then
                    table.insert(new_code, luac.CREATE_ABx(OP_LOADK, res2_reg, b - BITRK))
                else
                    table.insert(new_code, luac.CREATE_ABC(OP_MOVE, res2_reg, b, 0))
                end
                table.insert(new_code, luac.CREATE_ABC(OP_SETTABLE, a, res2_reg, res1_reg))
                count = count + 1
            else
                table.insert(new_code, ins)
            end
        else
            table.insert(new_code, ins)
        end

        insert_len[i] = #new_code - start_len - 1
        inserted_so_far = inserted_so_far + insert_len[i]
    end

    -- 9. 调整跳转
    if junk_jmp and junk_jmp.adjust_jumps then
        for i = 1, #proto.code do
            if insert_len[i] > 0 then
                local pos0 = i + insert_pos[i] + 1  -- 1-based
                junk_jmp.adjust_jumps(new_code, pos0, insert_len[i])
            end
        end
    end

    proto.code = new_code

    -- 10. 同步 lineinfo
    if proto.lineinfo then
        local new_lineinfo = {}
        for i = 1, #new_code do new_lineinfo[i] = 0 end
        for i = 1, #proto.lineinfo do
            if insert_pos[i] then
                new_lineinfo[i + insert_pos[i]] = proto.lineinfo[i]
            end
        end
        proto.lineinfo = new_lineinfo
    end

    -- 11. 更新 maxstacksize
    proto.maxstacksize = math.max(proto.maxstacksize, needed_stack)

    return count
end

-- 对整个 proto 树进行字符串加密
function str_encrypt.encrypt(proto, options)
    options = options or {}
    math.randomseed(os.time())
    local all_protos = collect_protos(proto)
    local total = 0
    for _, p in ipairs(all_protos) do
        total = total + str_encrypt.encrypt_function(p, options)
    end
    return total
end

return str_encrypt
