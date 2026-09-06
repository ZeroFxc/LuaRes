-- destr_encrypt.lua: 字符串加密反向
-- 识别 str_encrypt 产生的解密函数子proto + CLOSURE/MOVE/CALL/MOVE 解密序列
-- 用提取的key解密字符串常量，还原原始指令，移除解密函数
-- 用法: destr_encrypt.clean(proto)

local luac = require('luac')

local destr = {}

local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}

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

local function adjust_jumps_remove(code, remove_pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            local target = i + sbx + 1
            local delta = 0
            if i < remove_pos and target > remove_pos then
                delta = -n
            elseif i >= remove_pos and target < remove_pos then
                delta = n
            end
            if delta ~= 0 then
                local new_sbx = sbx + delta
                local new_bx = new_sbx + 131071
                code[i] = (code[i] & 0x3FFF) | (new_bx << 14)
            end
        end
    end
end

-- XOR 解密
local function xor_crypt(s, key)
    local bytes = {}
    for i = 1, #s do
        bytes[i] = string.char(string.byte(s, i) ~ key)
    end
    return table.concat(bytes)
end

-- 检查子proto是否是str_encrypt的解密函数
-- 特征: 常量池有 "byte"/"char"/"string", 代码有 BXOR, 是简单循环
local function is_decrypt_proto(p)
    if not p.k or not p.code then return false end
    local has_byte = false
    local has_char = false
    local has_string = false
    local has_bxor = false
    for i = 1, #p.k do
        if p.k[i] == "byte" then has_byte = true end
        if p.k[i] == "char" then has_char = true end
        if p.k[i] == "string" then has_string = true end
    end
    for i = 1, #p.code do
        if luac.GET_OPCODE(p.code[i]) == luac.OP_BXOR then has_bxor = true end
    end
    return has_byte and has_char and has_bxor
end

-- 从解密函数中提取XOR key
-- BXOR 指令的操作数是 LOADK 加载的数字常量
local function extract_decrypt_key(p)
    -- 找到 BXOR 指令，其操作数之一是常量（通过 LOADK 加载）
    for i = 1, #p.code do
        if luac.GET_OPCODE(p.code[i]) == luac.OP_BXOR then
            local b = luac.GETARG_B(p.code[i])
            local c = luac.GETARG_C(p.code[i])
            -- 向前找 LOADK 加载到 b 或 c 的指令
            for j = i - 1, math.max(1, i - 10), -1 do
                if luac.GET_OPCODE(p.code[j]) == luac.OP_LOADK then
                    local a = luac.GETARG_A(p.code[j])
                    local bx = luac.GETARG_Bx(p.code[j])
                    if a == b or a == c then
                        local val = p.k[bx + 1]
                        if type(val) == 'number' then
                            return math.floor(val)
                        end
                    end
                end
            end
        end
    end
    return 0x55  -- 默认key
end

-- 找到proto中的解密函数，返回 {idx, key} 或 nil
local function find_decrypt_proto(proto)
    if not proto.p then return nil end
    for i = 1, #proto.p do
        if is_decrypt_proto(proto.p[i]) then
            local key = extract_decrypt_key(proto.p[i])
            return {idx = i - 1, key = key, proto = proto.p[i]}
        end
    end
    return nil
end

-- 对单个函数进行字符串加密反向
function destr.clean_function(proto)
    local dec_info = find_decrypt_proto(proto)
    if not dec_info then return 0 end

    local key = dec_info.key
    local dec_idx = dec_info.idx
    local code = proto.code
    local count = 0
    local i = 1

    -- 先解密所有字符串常量
    -- 但需要先确定哪些常量是被加密的（被解密序列引用的）
    local encrypted_consts = {}

    while i <= #code - 4 do
        -- 模式: CLOSURE dec_reg, dec_idx + MOVE arg_reg, src + CALL dec_reg, 2, 2 + MOVE dst, dec_reg
        local op1 = luac.GET_OPCODE(code[i])
        if op1 == luac.OP_CLOSURE then
            local a1 = luac.GETARG_A(code[i])
            local bx1 = luac.GETARG_Bx(code[i])
            if bx1 == dec_idx then
                local op2 = luac.GET_OPCODE(code[i + 1])
                local op3 = luac.GET_OPCODE(code[i + 2])
                local op4 = luac.GET_OPCODE(code[i + 3])
                if op2 == luac.OP_MOVE and op3 == luac.OP_CALL and op4 == luac.OP_MOVE then
                    local mv_src = luac.GETARG_B(code[i + 1])
                    local call_a = luac.GETARG_A(code[i + 2])
                    local call_b = luac.GETARG_B(code[i + 2])
                    local call_c = luac.GETARG_C(code[i + 2])
                    local mv_dst = luac.GETARG_A(code[i + 3])
                    local mv_dst_src = luac.GETARG_B(code[i + 3])

                    if call_a == a1 and call_b == 2 and call_c == 2 and
                       mv_dst_src == a1 then
                        -- 找到解密序列
                        -- 检查前面是否有 LOADK mv_src, const_idx (加载加密字符串)
                        local loadk_pos = nil
                        local loadk_const = nil
                        if i > 1 then
                            local prev_op = luac.GET_OPCODE(code[i - 1])
                            if prev_op == luac.OP_LOADK then
                                local pa = luac.GETARG_A(code[i - 1])
                                if pa == mv_src then
                                    loadk_pos = i - 1
                                    loadk_const = luac.GETARG_Bx(code[i - 1])
                                end
                            end
                        end

                        if loadk_pos then
                            -- 标记这个常量是被加密的
                            encrypted_consts[loadk_const] = true

                            -- 检查这是 GETTABUP/GETTABLE 模式还是纯 LOADK 模式
                            -- GETTABUP模式: 前面还有 GETUPVAL table_reg, b
                            -- GETTABLE模式: 后面还有 GETTABLE a, b, mv_dst

                            -- 检查后面是否有 GETTABLE 使用 mv_dst 作为 key
                            local gettable_pos = nil
                            if i + 4 <= #code then
                                local next_op = luac.GET_OPCODE(code[i + 4])
                                if next_op == luac.OP_GETTABLE then
                                    local ga = luac.GETARG_A(code[i + 4])
                                    local gb = luac.GETARG_B(code[i + 4])
                                    local gc = luac.GETARG_C(code[i + 4])
                                    if gc == mv_dst then
                                        gettable_pos = i + 4
                                    end
                                end
                            end

                            if gettable_pos then
                                -- GETTABLE 或 GETTABUP 模式
                                -- 检查前面是否有 GETUPVAL (GETTABUP模式)
                                local getupval_pos = nil
                                if loadk_pos > 1 then
                                    local prev_op = luac.GET_OPCODE(code[loadk_pos - 1])
                                    if prev_op == luac.OP_GETUPVAL then
                                        getupval_pos = loadk_pos - 1
                                    end
                                end

                                if getupval_pos then
                                    -- GETTABUP 模式: GETUPVAL + LOADK + 解密序列 + GETTABLE
                                    -- 还原为 GETTABUP ga, gu_b, loadk_const+256
                                    local gu_b = luac.GETARG_B(code[getupval_pos])
                                    local ga = luac.GETARG_A(code[gettable_pos])
                                    code[getupval_pos] = luac.CREATE_ABC(luac.OP_GETTABUP, ga, gu_b, loadk_const + 256)
                                    -- 删除从 loadk_pos 到 gettable_pos 的指令
                                    local remove_start = getupval_pos + 1
                                    local remove_count = gettable_pos - getupval_pos
                                    for j = 1, remove_count do
                                        table.remove(code, remove_start)
                                    end
                                    adjust_jumps_remove(code, remove_start, remove_count)
                                    count = count + 1
                                    i = getupval_pos + 1
                                else
                                    -- GETTABLE 模式: LOADK + 解密序列 + GETTABLE
                                    -- 还原为 GETTABLE ga, gb, loadk_const+256
                                    local ga = luac.GETARG_A(code[gettable_pos])
                                    local gb = luac.GETARG_B(code[gettable_pos])
                                    code[loadk_pos] = luac.CREATE_ABC(luac.OP_GETTABLE, ga, gb, loadk_const + 256)
                                    local remove_start = loadk_pos + 1
                                    local remove_count = gettable_pos - loadk_pos
                                    for j = 1, remove_count do
                                        table.remove(code, remove_start)
                                    end
                                    adjust_jumps_remove(code, remove_start, remove_count)
                                    count = count + 1
                                    i = loadk_pos + 1
                                end
                            else
                                -- 纯 LOADK 模式: LOADK + 解密序列
                                -- LOADK 已经加载了加密字符串到 mv_src，解密后到 mv_dst
                                -- 如果 mv_src == mv_dst，直接保留 LOADK（常量会被解密）
                                -- 如果 mv_src ~= mv_dst，需要 MOVE
                                if mv_src == mv_dst then
                                    -- 删除解密序列 (CLOSURE+MOVE+CALL+MOVE)
                                    for j = 1, 4 do
                                        table.remove(code, i)
                                    end
                                    adjust_jumps_remove(code, i, 4)
                                else
                                    -- 替换为 MOVE mv_dst, mv_src
                                    code[i] = luac.CREATE_ABC(luac.OP_MOVE, mv_dst, mv_src, 0)
                                    for j = 1, 3 do
                                        table.remove(code, i + 1)
                                    end
                                    adjust_jumps_remove(code, i + 1, 3)
                                end
                                count = count + 1
                                i = i + 1
                            end
                            goto continue
                        end
                    end
                end
            end
        end
        i = i + 1
        ::continue::
    end

    -- 解密被标记的字符串常量
    for idx in pairs(encrypted_consts) do
        if type(proto.k[idx + 1]) == 'string' then
            proto.k[idx + 1] = xor_crypt(proto.k[idx + 1], key)
        end
    end

    -- 移除解密函数子proto
    if proto.p and #proto.p > dec_idx then
        table.remove(proto.p, dec_idx + 1)
        -- 调整其他 CLOSURE 指令的 Bx 索引
        for i = 1, #code do
            if luac.GET_OPCODE(code[i]) == luac.OP_CLOSURE then
                local bx = luac.GETARG_Bx(code[i])
                if bx > dec_idx then
                    code[i] = luac.CREATE_ABx(luac.OP_CLOSURE, luac.GETARG_A(code[i]), bx - 1)
                end
            end
        end
    end

    return count
end

-- 对整个 proto 树进行字符串加密反向
function destr.clean(proto)
    local all_protos = collect_protos(proto)
    local total = 0
    for _, p in ipairs(all_protos) do
        total = total + destr.clean_function(p)
    end
    return total
end

return destr
