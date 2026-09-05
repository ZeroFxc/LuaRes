-- num_obfuscate.lua: 数字常量混淆
-- 把数字常量替换为数学表达式的结果（加法/异或/减法）

local luac = require('luac')
local junk_jmp = require('junk_jmp')

local num_obf = {}

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

-- 找出函数中所有引用数字的 LOADK 指令
local function find_number_loadks(proto)
    local number_set = {}
    local number_indices = {}
    for i = 1, #proto.k do
        if type(proto.k[i]) == 'number' and proto.k[i] == math.floor(proto.k[i]) then
            -- 只混淆整数，且范围在合理范围内
            local n = proto.k[i]
            if n >= -1000000 and n <= 1000000 and n ~= 0 and n ~= 1 then
                number_set[i - 1] = true  -- 0-based
                number_indices[#number_indices + 1] = i - 1
            end
        end
    end

    local loadks = {}
    for i = 1, #proto.code do
        local op = luac.GET_OPCODE(proto.code[i])
        if op == luac.OP_LOADK then
            local bx = luac.GETARG_Bx(proto.code[i])
            if number_set[bx] then
                loadks[#loadks + 1] = {
                    pos = i,
                    reg = luac.GETARG_A(proto.code[i]),
                    const_idx = bx,
                    value = proto.k[bx + 1]
                }
            end
        end
    end
    return loadks, number_indices
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

-- 对单个函数进行数字混淆
function num_obf.obfuscate_function(proto, options)
    options = options or {}
    local rate = options.rate or 0.5

    local loadks, number_indices = find_number_loadks(proto)
    if #loadks == 0 then return 0 end

    local max_reg = calc_max_reg(proto)
    local tmp1 = math.min(max_reg + 2, 245)
    local tmp2 = tmp1 + 1

    local count = 0
    local new_code = {}

    for i = 1, #proto.code do
        local inst = proto.code[i]
        local op = luac.GET_OPCODE(inst)

        if op == luac.OP_LOADK then
            local bx = luac.GETARG_Bx(inst)
            local is_number = false
            local value = nil
            for _, idx in ipairs(number_indices) do
                if bx == idx then
                    is_number = true
                    value = proto.k[idx + 1]
                    break
                end
            end

            if is_number and math.random() < rate then
                local a = luac.GETARG_A(inst)
                local method = math.random(1, 3)  -- 1=add, 2=xor, 3=sub
                local operand = math.random(1, 1000)

                local v1, v2, op_op
                if method == 1 then
                    -- 加法：value = operand + (value - operand)
                    v1 = operand
                    v2 = value - operand
                    op_op = luac.OP_ADD
                elseif method == 2 then
                    -- 异或：value = operand ~ (value ~ operand)
                    v1 = operand
                    v2 = value ~ operand
                    op_op = luac.OP_BXOR
                else
                    -- 减法：value = operand - (operand - value)
                    v1 = operand
                    v2 = operand - value
                    op_op = luac.OP_SUB
                end

                -- 添加两个新常量
                proto.k[#proto.k + 1] = v1
                local idx1 = #proto.k - 1  -- 0-based
                proto.k[#proto.k + 1] = v2
                local idx2 = #proto.k - 1  -- 0-based

                -- LOADK tmp1, v1
                table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, tmp1, idx1))
                -- LOADK tmp2, v2
                table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, tmp2, idx2))
                -- ADD/SUB/BXOR a, tmp1, tmp2
                table.insert(new_code, luac.CREATE_ABC(op_op, a, tmp1, tmp2))

                count = count + 1
            else
                table.insert(new_code, inst)
            end
        else
            table.insert(new_code, inst)
        end
    end

    -- 调整 JMP 跳转
    if junk_jmp and junk_jmp.adjust_jumps then
        junk_jmp.adjust_jumps(new_code, 1, #new_code)
    end

    proto.code = new_code
    proto.maxstacksize = math.min(math.max(proto.maxstacksize, tmp2 + 1), 250)

    return count
end

-- 对整个 proto 树进行数字混淆
function num_obf.obfuscate(proto, options)
    options = options or {}
    local all_protos = collect_protos(proto)
    local total = 0
    for _, p in ipairs(all_protos) do
        total = total + num_obf.obfuscate_function(p, options)
    end
    return total
end

return num_obf
