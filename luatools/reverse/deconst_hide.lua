-- deconst_hide.lua: 常量池隐藏反向
-- 识别 const_hide 生成的截取函数子proto + 截取序列，从 blob 还原原始字符串
-- 用法: deconst_hide.clean(proto)

local luac = require('luac')

local deconst = {}

local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}

-- 识别截取函数: function(s, i, j) return s:sub(i, j) end
-- 特征: 3个参数, 常量有 "sub", 指令有 SELF+CALL+RETURN
local function is_sub_proto(p)
    if not p.k or not p.code then return false end
    if p.numparams ~= 3 then return false end
    local has_sub = false
    for i = 1, #p.k do
        if p.k[i] == "sub" then has_sub = true end
    end
    if not has_sub then return false end
    local has_self = false
    local has_call = false
    for i = 1, #p.code do
        local op = luac.GET_OPCODE(p.code[i])
        if op == 12 then has_self = true end
        if op == 36 then has_call = true end
    end
    return has_self and has_call
end

-- 找到截取函数子proto，返回 {idx, proto} 或 nil
local function find_sub_proto(proto)
    if not proto.p then return nil end
    for i = 1, #proto.p do
        if is_sub_proto(proto.p[i]) then
            return {idx = i - 1, proto = proto.p[i]}
        end
    end
    return nil
end

-- 调整跳转: 删除 pos 位置开始的 n 条指令
local function adjust_jumps_remove(code, pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            local target = i + sbx + 1
            local delta = 0
            if i < pos and target > pos then
                delta = -n
            elseif i >= pos and target < pos then
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

-- 确保常量池中有指定字符串，返回其 0-based 索引
local function ensure_string_const(proto, s)
    for i = 1, #proto.k do
        if proto.k[i] == s then return i - 1 end
    end
    -- 找一个 nil 槽位
    for i = 1, #proto.k do
        if proto.k[i] == nil then
            proto.k[i] = s
            return i - 1
        end
    end
    proto.k[#proto.k + 1] = s
    return #proto.k - 1
end

-- 对单个 proto 处理
function deconst.clean_function(proto)
    local sub_info = find_sub_proto(proto)
    if not sub_info then return 0 end

    local sub_idx = sub_info.idx
    local code = proto.code
    local count = 0
    local i = 1

    while i <= #code - 4 do
        -- 检测截取序列: LOADK + CLOSURE(sub) + LOADK + LOADK + CALL
        local op1 = luac.GET_OPCODE(code[i])
        if op1 == 1 then  -- LOADK
            local a1 = luac.GETARG_A(code[i])
            local bx1 = luac.GETARG_Bx(code[i])
            local op2 = luac.GET_OPCODE(code[i + 1])
            if op2 == 44 then  -- CLOSURE
                local a2 = luac.GETARG_A(code[i + 1])
                local bx2 = luac.GETARG_Bx(code[i + 1])
                if bx2 == sub_idx then
                    local op3 = luac.GET_OPCODE(code[i + 2])
                    local op4 = luac.GET_OPCODE(code[i + 3])
                    local op5 = luac.GET_OPCODE(code[i + 4])
                    if op3 == 1 and op4 == 1 and op5 == 36 then  -- LOADK, LOADK, CALL
                        local call_a = luac.GETARG_A(code[i + 4])
                        local call_b = luac.GETARG_B(code[i + 4])
                        local call_c = luac.GETARG_C(code[i + 4])
                        if call_a == a2 and call_b == 4 and call_c == 2 then
                            -- 确认是截取序列
                            local blob_kidx = bx1
                            local off_kidx = luac.GETARG_Bx(code[i + 2])
                            local endp_kidx = luac.GETARG_Bx(code[i + 3])
                            local blob = proto.k[blob_kidx + 1]
                            local offset = proto.k[off_kidx + 1]
                            local endpos = proto.k[endp_kidx + 1]

                            if type(blob) == 'string' and type(offset) == 'number' and type(endpos) == 'number' then
                                local orig_str = blob:sub(offset, endpos)
                                local str_kidx = ensure_string_const(proto, orig_str)
                                local sub_reg = a2

                                -- 看后面跟的是什么指令
                                local next_i = i + 5
                                local next_op = (next_i <= #code) and luac.GET_OPCODE(code[next_i]) or -1

                                if next_op == 0 then  -- MOVE dst, sub_reg
                                    local mv_a = luac.GETARG_A(code[next_i])
                                    local mv_b = luac.GETARG_B(code[next_i])
                                    if mv_b == sub_reg then
                                        -- LOADK 模式: 还原为 LOADK mv_a, str_kidx
                                        code[i] = luac.CREATE_ABx(1, mv_a, str_kidx)
                                        for j = 1, 5 do table.remove(code, i + 1) end
                                        adjust_jumps_remove(code, i + 1, 5)
                                        count = count + 1
                                        goto continue
                                    end

                                elseif next_op == 7 then  -- GETTABLE a, b, sub_reg
                                    local ga = luac.GETARG_A(code[next_i])
                                    local gb = luac.GETARG_B(code[next_i])
                                    local gc = luac.GETARG_C(code[next_i])
                                    if gc == sub_reg then
                                        -- 检查前面是否有 GETUPVAL (GETTABUP 模式)
                                        local getupval_pos = nil
                                        if i > 1 then
                                            local prev_op = luac.GET_OPCODE(code[i - 1])
                                            if prev_op == 5 then  -- GETUPVAL
                                                local gu_a = luac.GETARG_A(code[i - 1])
                                                if gu_a == gb then
                                                    getupval_pos = i - 1
                                                end
                                            end
                                        end
                                        if getupval_pos then
                                            -- GETTABUP 模式: 还原为 GETTABUP ga, gu_b, str_kidx+256
                                            local gu_b = luac.GETARG_B(code[getupval_pos])
                                            code[getupval_pos] = luac.CREATE_ABC(6, ga, gu_b, str_kidx + 256)
                                            -- 删除从 i 到 next_i 的指令 (截取序列 + GETTABLE)
                                            local remove_start = i
                                            local remove_count = next_i - i + 1
                                            for j = 1, remove_count do table.remove(code, remove_start) end
                                            adjust_jumps_remove(code, remove_start, remove_count)
                                            count = count + 1
                                            i = getupval_pos + 1
                                            goto continue
                                        else
                                            -- GETTABLE 模式: 还原为 GETTABLE ga, gb, str_kidx+256
                                            code[i] = luac.CREATE_ABC(7, ga, gb, str_kidx + 256)
                                            for j = 1, 5 do table.remove(code, i + 1) end
                                            adjust_jumps_remove(code, i + 1, 5)
                                            count = count + 1
                                            goto continue
                                        end
                                    end

                                elseif next_op == 10 then  -- SETTABLE a, sub_reg, c
                                    local sa = luac.GETARG_A(code[next_i])
                                    local sb = luac.GETARG_B(code[next_i])
                                    local sc = luac.GETARG_C(code[next_i])
                                    if sb == sub_reg then
                                        -- 检查前面是否有 GETUPVAL (SETTABUP 模式)
                                        local getupval_pos = nil
                                        if i > 1 then
                                            local prev_op = luac.GET_OPCODE(code[i - 1])
                                            if prev_op == 5 then  -- GETUPVAL
                                                local gu_a = luac.GETARG_A(code[i - 1])
                                                if gu_a == sa then
                                                    getupval_pos = i - 1
                                                end
                                            end
                                        end
                                        if getupval_pos then
                                            -- SETTABUP 模式: 还原为 SETTABUP sc(=value), gu_b, str_kidx+256
                                            -- SETTABUP A B C: Upvalue[B][K(C)] = R(A)
                                            -- 原 SETTABLE tmp, sub_reg, a 中 a=tmp, sub_reg=key, c=value
                                            -- 但我们的 forward 生成的是 SETTABLE UPVAL_REG, SUB_REG, R_a
                                            -- 所以 sa=UPVAL_REG, sb=SUB_REG, sc=R_a(value)
                                            local gu_b = luac.GETARG_B(code[getupval_pos])
                                            code[getupval_pos] = luac.CREATE_ABC(8, sc, gu_b, str_kidx + 256)
                                            local remove_start = i
                                            local remove_count = next_i - i + 1
                                            for j = 1, remove_count do table.remove(code, remove_start) end
                                            adjust_jumps_remove(code, remove_start, remove_count)
                                            count = count + 1
                                            i = getupval_pos + 1
                                            goto continue
                                        else
                                            -- SETTABLE 模式: 还原为 SETTABLE sa, str_kidx+256, sc
                                            code[i] = luac.CREATE_ABC(10, sa, str_kidx + 256, sc)
                                            for j = 1, 5 do table.remove(code, i + 1) end
                                            adjust_jumps_remove(code, i + 1, 5)
                                            count = count + 1
                                            goto continue
                                        end
                                    end

                                elseif next_op == 12 then  -- SELF a, b, sub_reg
                                    local sa = luac.GETARG_A(code[next_i])
                                    local sb = luac.GETARG_B(code[next_i])
                                    local sc = luac.GETARG_C(code[next_i])
                                    if sc == sub_reg then
                                        -- SELF 模式: 还原为 SELF sa, sb, str_kidx+256
                                        code[i] = luac.CREATE_ABC(12, sa, sb, str_kidx + 256)
                                        for j = 1, 5 do table.remove(code, i + 1) end
                                        adjust_jumps_remove(code, i + 1, 5)
                                        count = count + 1
                                        goto continue
                                    end
                                end

                                -- 如果后面没有匹配的指令，至少还原截取序列为 LOADK
                                -- (sub_reg 中有截取结果，但没人用——不应该发生)
                            end
                        end
                    end
                end
            end
        end
        i = i + 1
        ::continue::
    end

    -- 移除截取函数子proto
    if proto.p and #proto.p > sub_idx then
        table.remove(proto.p, sub_idx + 1)
        for j = 1, #code do
            if luac.GET_OPCODE(code[j]) == 44 then
                local bx = luac.GETARG_Bx(code[j])
                if bx > sub_idx then
                    code[j] = luac.CREATE_ABx(44, luac.GETARG_A(code[j]), bx - 1)
                end
            end
        end
    end

    return count
end

-- 递归处理整个 proto 树
-- 先处理子 proto, 再处理当前 proto (与正向对称)
function deconst.clean(proto)
    local total = 0
    if proto.p then
        for i = 1, #proto.p do
            total = total + deconst.clean(proto.p[i])
        end
    end
    total = total + deconst.clean_function(proto)
    return total
end

return deconst
