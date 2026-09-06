-- destr_split.lua: 字符串分割混淆反向
-- 识别 str_split 产生的 LOADK段+CONCAT+使用 模式，拼接还原原始字符串
-- 用法: destr_split.clean(proto)

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

-- 找到或添加字符串常量，返回0-based索引
local function find_or_add_string(proto, s)
    for i = 1, #proto.k do
        if proto.k[i] == s and type(proto.k[i]) == 'string' then
            return i - 1
        end
    end
    proto.k[#proto.k + 1] = s
    return #proto.k - 1
end

-- 检查从位置 pos 开始是否有连续的 LOADK 加载到连续寄存器
-- 返回 {start_pos, n, base_reg, segments={字符串列表}} 或 nil
local function find_loadk_sequence(code, proto, pos)
    if pos > #code then return nil end
    local op = luac.GET_OPCODE(code[pos])
    if op ~= luac.OP_LOADK then return nil end

    local base_reg = luac.GETARG_A(code[pos])
    -- str_split 使用高寄存器 (tmp_base = min(max_reg+5, 240))
    if base_reg < 10 then return nil end

    local segments = {}
    local n = 0
    local i = pos
    while i <= #code do
        local cur_op = luac.GET_OPCODE(code[i])
        if cur_op ~= luac.OP_LOADK then break end
        local cur_a = luac.GETARG_A(code[i])
        if cur_a ~= base_reg + n then break end
        local bx = luac.GETARG_Bx(code[i])
        local val = proto.k[bx + 1]
        if type(val) ~= 'string' then break end
        segments[#segments + 1] = val
        n = n + 1
        i = i + 1
    end

    if n < 2 then return nil end  -- 至少2段才是分割混淆

    -- 检查后面是否有 CONCAT base_reg, base_reg, base_reg+n-1
    if i <= #code then
        local concat_op = luac.GET_OPCODE(code[i])
        if concat_op == luac.OP_CONCAT then
            local ca = luac.GETARG_A(code[i])
            local cb = luac.GETARG_B(code[i])
            local cc = luac.GETARG_C(code[i])
            if ca == base_reg and cb == base_reg and cc == base_reg + n - 1 then
                return {
                    start_pos = pos,
                    n = n,
                    base_reg = base_reg,
                    segments = segments,
                    concat_pos = i,
                    after_concat = i + 1
                }
            end
        end
    end

    return nil
end

-- 拼接段得到原始字符串
local function concat_segments(segments)
    return table.concat(segments)
end

-- 对单个函数进行字符串分割反向
function destr.clean_function(proto)
    local code = proto.code
    local count = 0
    local i = 1

    while i <= #code do
        local seq = find_loadk_sequence(code, proto, i)
        if not seq then
            i = i + 1
            goto continue
        end

        local original = concat_segments(seq.segments)
        local orig_idx = find_or_add_string(proto, original)
        local after = seq.after_concat

        if after > #code then
            i = i + 1
            goto continue
        end

        local next_op = luac.GET_OPCODE(code[after])

        -- 模式1: LOADK序列 + CONCAT + MOVE a, base_reg
        if next_op == luac.OP_MOVE then
            local ma = luac.GETARG_A(code[after])
            local mb = luac.GETARG_B(code[after])
            if mb == seq.base_reg then
                -- 还原为 LOADK ma, orig_idx
                code[i] = luac.CREATE_ABx(luac.OP_LOADK, ma, orig_idx)
                -- 删除从 i+1 到 after 的所有指令 (n条LOADK + 1条CONCAT + 1条MOVE - 1条已替换)
                local remove_count = seq.n + 1  -- n-1条LOADK + 1条CONCAT + 1条MOVE
                for j = 1, remove_count do
                    table.remove(code, i + 1)
                end
                adjust_jumps_remove(code, i + 1, remove_count)
                count = count + 1
                i = i + 1
                goto continue
            end
        end

        -- 模式2: 前面有 GETUPVAL table_reg, b + LOADK序列 + CONCAT + GETTABLE a, table_reg, base_reg
        -- 检查 i-1 是否是 GETUPVAL
        if i > 1 then
            local prev_op = luac.GET_OPCODE(code[i - 1])
            if prev_op == luac.OP_GETUPVAL then
                local pa = luac.GETARG_A(code[i - 1])
                local pb = luac.GETARG_B(code[i - 1])
                if next_op == luac.OP_GETTABLE then
                    local ga = luac.GETARG_A(code[after])
                    local gb = luac.GETARG_B(code[after])
                    local gc = luac.GETARG_C(code[after])
                    if gb == pa and gc == seq.base_reg then
                        -- 还原为 GETTABUP ga, pb, orig_idx+256
                        code[i - 1] = luac.CREATE_ABC(luac.OP_GETTABUP, ga, pb, orig_idx + 256)
                        -- 删除从 i 到 after 的所有指令
                        local remove_count = seq.n + 1 + 1  -- n条LOADK + 1条CONCAT + 1条GETTABLE
                        for j = 1, remove_count do
                            table.remove(code, i)
                        end
                        adjust_jumps_remove(code, i, remove_count)
                        count = count + 1
                        i = i
                        goto continue
                    end
                end
            end
        end

        -- 模式3: LOADK序列 + CONCAT + GETTABLE a, b, base_reg (b不是高寄存器)
        if next_op == luac.OP_GETTABLE then
            local ga = luac.GETARG_A(code[after])
            local gb = luac.GETARG_B(code[after])
            local gc = luac.GETARG_C(code[after])
            if gc == seq.base_reg and gb ~= seq.base_reg then
                -- 检查是否是 SELF 模式: 前面有 MOVE a+1, b
                local is_self = false
                local self_a = nil
                if i > 1 then
                    local prev_op = luac.GET_OPCODE(code[i - 1])
                    if prev_op == luac.OP_MOVE then
                        local pma = luac.GETARG_A(code[i - 1])
                        local pmb = luac.GETARG_B(code[i - 1])
                        if pma == ga + 1 and pmb == gb then
                            is_self = true
                            self_a = ga
                        end
                    end
                end

                if is_self then
                    -- 还原为 SELF ga, gb, orig_idx+256
                    code[i - 1] = luac.CREATE_ABC(luac.OP_SELF, ga, gb, orig_idx + 256)
                    local remove_count = seq.n + 1 + 1
                    for j = 1, remove_count do
                        table.remove(code, i)
                    end
                    adjust_jumps_remove(code, i, remove_count)
                    count = count + 1
                    i = i
                    goto continue
                else
                    -- 普通 GETTABLE 模式
                    code[i] = luac.CREATE_ABC(luac.OP_GETTABLE, ga, gb, orig_idx + 256)
                    local remove_count = seq.n + 1  -- n-1条LOADK + 1条CONCAT + 1条GETTABLE - 1
                    for j = 1, remove_count do
                        table.remove(code, i + 1)
                    end
                    adjust_jumps_remove(code, i + 1, remove_count)
                    count = count + 1
                    i = i + 1
                    goto continue
                end
            end
        end

        -- 模式4: MOVE val_reg, a + GETUPVAL table_reg, b + LOADK序列 + CONCAT + SETTABLE table_reg, base_reg, val_reg
        if next_op == luac.OP_SETTABLE then
            local sa = luac.GETARG_A(code[after])
            local sb = luac.GETARG_B(code[after])
            local sc = luac.GETARG_C(code[after])
            if sb == seq.base_reg then
                -- 检查前面是否有 MOVE val_reg, x + GETUPVAL table_reg, b
                if i >= 3 then
                    local op_m1 = luac.GET_OPCODE(code[i - 1])
                    local op_m2 = luac.GET_OPCODE(code[i - 2])
                    if op_m1 == luac.OP_GETUPVAL and op_m2 == luac.OP_MOVE then
                        local gu_a = luac.GETARG_A(code[i - 1])
                        local gu_b = luac.GETARG_B(code[i - 1])
                        local mv_a = luac.GETARG_A(code[i - 2])
                        local mv_b = luac.GETARG_B(code[i - 2])
                        if sa == gu_a and sc == mv_a then
                            -- SETTABUP 模式: 还原为 SETTABUP mv_b, gu_b, orig_idx+256
                            code[i - 2] = luac.CREATE_ABC(luac.OP_SETTABUP, mv_b, gu_b, orig_idx + 256)
                            local remove_count = 1 + seq.n + 1 + 1  -- GETUPVAL + nLOADK + CONCAT + SETTABLE
                            for j = 1, remove_count do
                                table.remove(code, i - 1)
                            end
                            adjust_jumps_remove(code, i - 1, remove_count)
                            count = count + 1
                            i = i - 1
                            goto continue
                        end
                    elseif op_m1 == luac.OP_MOVE then
                        -- SETTABLE 模式: MOVE val_reg, a + LOADK序列 + CONCAT + SETTABLE b, base_reg, val_reg
                        local mv_a = luac.GETARG_A(code[i - 1])
                        local mv_b = luac.GETARG_B(code[i - 1])
                        if sc == mv_a then
                            code[i - 1] = luac.CREATE_ABC(luac.OP_SETTABLE, mv_b, sa, orig_idx + 256)
                            -- 等等，SETTABLE 的格式是 SETTABLE a, b, c 其中 a=table, b=key, c=value
                            -- 原始 SETTABLE a, b, c(>=256表示常量)
                            -- str_split 产生的是 SETTABLE b, base_reg, val_reg
                            -- 所以原始是 SETTABLE mv_b? 不对
                            -- 原始 SETTABLE a(table), b(key const), c(value)
                            -- str_split: MOVE val_reg, a(value) + ... + SETTABLE b(table), base_reg(key), val_reg(value)
                            -- 还原: SETTABLE b, orig_idx+256, a
                            -- 但 a 是 mv_b (value寄存器), b 是 sa (table寄存器)
                            code[i - 1] = luac.CREATE_ABC(luac.OP_SETTABLE, sa, orig_idx + 256, mv_b)
                            local remove_count = seq.n + 1 + 1
                            for j = 1, remove_count do
                                table.remove(code, i)
                            end
                            adjust_jumps_remove(code, i, remove_count)
                            count = count + 1
                            i = i
                            goto continue
                        end
                    end
                end
            end
        end

        i = i + 1
        ::continue::
    end

    return count
end

-- 对整个 proto 树进行字符串分割反向
function destr.clean(proto)
    local all_protos = collect_protos(proto)
    local total = 0
    for _, p in ipairs(all_protos) do
        total = total + destr.clean_function(p)
    end
    return total
end

return destr
