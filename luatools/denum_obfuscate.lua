-- denum_obfuscate.lua: 数字混淆反向
-- 识别 num_obfuscate 产生的模式: LOADK tmp1,v1 + LOADK tmp2,v2 + ADD/SUB/BXOR a,tmp1,tmp2
-- 还原为 LOADK a, result
-- 用法: denum_obfuscate.clean(proto)

local luac = require('luac')

local denum = {}

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

-- 调整跳转偏移（删除指令后）
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

-- 找到或添加数字常量
local function find_or_add_number(proto, num)
    for i = 1, #proto.k do
        if type(proto.k[i]) == 'number' and proto.k[i] == num then
            return i - 1
        end
    end
    proto.k[#proto.k + 1] = num
    return #proto.k - 1
end

-- 检查常量是否只被指定位置的 LOADK 引用
local function const_used_only_at(proto, const_idx, positions)
    local count = 0
    for i = 1, #proto.code do
        local op = luac.GET_OPCODE(proto.code[i])
        if op == luac.OP_LOADK then
            local bx = luac.GETARG_Bx(proto.code[i])
            if bx == const_idx then
                for _, p in ipairs(positions) do
                    if i == p then count = count + 1 end
                end
            end
        elseif op == luac.OP_GETTABUP or op == luac.OP_GETTABLE or
               op == luac.OP_SETTABUP or op == luac.OP_SETTABLE or op == luac.OP_SELF then
            local c = luac.GETARG_C(proto.code[i])
            if c >= 256 then
                local idx = c - 256
                if idx == const_idx then return false end
            end
        end
    end
    return count == #positions
end

-- 对单个函数进行数字混淆反向
function denum.clean_function(proto)
    local code = proto.code
    local count = 0
    local i = 1

    while i <= #code - 2 do
        local op1 = luac.GET_OPCODE(code[i])
        local op2 = luac.GET_OPCODE(code[i + 1])
        local op3 = luac.GET_OPCODE(code[i + 2])

        -- 模式: LOADK + LOADK + ADD/SUB/BXOR
        if op1 == luac.OP_LOADK and op2 == luac.OP_LOADK and
           (op3 == luac.OP_ADD or op3 == luac.OP_SUB or op3 == luac.OP_BXOR) then

            local a1 = luac.GETARG_A(code[i])
            local bx1 = luac.GETARG_Bx(code[i])
            local a2 = luac.GETARG_A(code[i + 1])
            local bx2 = luac.GETARG_Bx(code[i + 1])
            local a3 = luac.GETARG_A(code[i + 2])
            local b3 = luac.GETARG_B(code[i + 2])
            local c3 = luac.GETARG_C(code[i + 2])

            -- 检查: 第三条指令的 B/C 引用前两条的目标寄存器
            -- 且前两条的目标寄存器是临时寄存器（不等于 a3）
            if (b3 == a1 and c3 == a2) or (b3 == a2 and c3 == a1) then
                if a1 ~= a3 and a2 ~= a3 and a1 ~= a2 then
                    -- 检查常量是否是数字
                    local v1 = proto.k[bx1 + 1]
                    local v2 = proto.k[bx2 + 1]
                    if type(v1) == 'number' and type(v2) == 'number' then
                        -- 计算结果
                        local result
                        if op3 == luac.OP_ADD then
                            result = v1 + v2
                        elseif op3 == luac.OP_SUB then
                            -- SUB: a = b - c, 需要确定哪个是被减数
                            if b3 == a1 then
                                result = v1 - v2
                            else
                                result = v2 - v1
                            end
                        elseif op3 == luac.OP_BXOR then
                            result = ((v1 // 1) ~ (v2 // 1))
                            -- 保持整数
                            if result == math.floor(result) then
                                result = result
                            end
                        end

                        if result ~= nil and type(result) == 'number' then
                            -- 找到或添加结果常量
                            local result_idx = find_or_add_number(proto, result)

                            -- 替换为 LOADK a3, result_idx
                            code[i] = luac.CREATE_ABx(luac.OP_LOADK, a3, result_idx)

                            -- 删除后面两条
                            table.remove(code, i + 2)
                            table.remove(code, i + 1)
                            adjust_jumps_remove(code, i + 1, 2)

                            count = count + 1
                            i = i + 1
                        else
                            i = i + 1
                        end
                    else
                        i = i + 1
                    end
                else
                    i = i + 1
                end
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end

    return count
end

-- 对整个 proto 树进行数字混淆反向
function denum.clean(proto)
    local all_protos = collect_protos(proto)
    local total = 0
    for _, p in ipairs(all_protos) do
        total = total + denum.clean_function(p)
    end
    return total
end

return denum
