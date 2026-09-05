-- de_junk_obfuscate.lua - 去除 luac_obfuscate 注入的垃圾指令
-- luac_obfuscate 模式: 原始指令 + JMP sBx=N(6-21) + [随机垃圾 N-1 条]
-- 逻辑指令(LOADBOOL/EQ/LT/LE/TEST/TESTSET)有两个 JMP
-- TFORCALL 不注入垃圾
--
-- 用法: local de_junk = require("de_junk_obfuscate"); de_junk.remove(proto)

local luac = require("luac")

local de_junk_obfuscate = {}

local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}
local LOGICAL_OPS = {[3]=true,[31]=true,[32]=true,[33]=true,[34]=true,[35]=true}

local function adjust_jumps_remove(code, remove_pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            if op == 30 and sbx == 0 then
                -- skip
            else
                local target = i + sbx + 1
                local delta = 0
                if i < remove_pos and target >= remove_pos then
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
end

-- 检查从 pos 开始的 n 条指令是否是随机垃圾
-- luac_obfuscate 注入的垃圾是 math.random(0, 0x1099FFFFF), 操作码 0-63 均匀分布
-- 无效操作码(47-63)占 26.6%, 真实代码中无效操作码应为 0%
local function is_junk_block(code, pos, n, num_consts)
    if pos + n - 1 > #code then return false end
    local invalid_op_count = 0
    local high_reg_count = 0
    local bad_const_count = 0
    for i = pos, pos + n - 1 do
        local inst = code[i]
        local op = inst % 64
        local a = (inst >> 6) & 0xFF
        local b = (inst >> 23) & 0x1FF
        local c = (inst >> 14) & 0x1FF

        -- 无效操作码 (>46)
        if op > 46 then invalid_op_count = invalid_op_count + 1 end
        -- 高寄存器 (>= 200)
        if a >= 200 then high_reg_count = high_reg_count + 1 end
        if b < 256 and b >= 200 then high_reg_count = high_reg_count + 1 end
        if c < 256 and c >= 200 then high_reg_count = high_reg_count + 1 end
        -- 常量索引超出范围
        if op == 1 and b >= num_consts then bad_const_count = bad_const_count + 1 end
        if b >= 256 and (b - 256) >= num_consts then bad_const_count = bad_const_count + 1 end
        if c >= 256 and (c - 256) >= num_consts then bad_const_count = bad_const_count + 1 end
    end
    -- 要求: 无效操作码 >= 20% 或 (高寄存器 >= 30% 且 坏常量 >= 10%)
    local invalid_ratio = invalid_op_count / n
    local high_reg_ratio = high_reg_count / (n * 3)
    local bad_const_ratio = bad_const_count / n
    if invalid_ratio >= 0.20 then return true end
    if high_reg_ratio >= 0.30 and bad_const_ratio >= 0.10 then return true end
    return false
end

local function remove_in_func(p)
    local removed = 0
    local i = 1
    while i <= #p.code do
        local inst = p.code[i]
        local op = inst % 64

        -- TFORCALL 不注入垃圾
        if op == 41 then
            i = i + 1
        -- 检查下一条是否是 JMP sBx=N (6-21), A=0
        elseif i + 1 <= #p.code then
            local next_inst = p.code[i + 1]
            local next_op = next_inst % 64
            local next_a = (next_inst >> 6) & 0xFF
            if next_op == 30 and next_a == 0 then  -- JMP, A=0
                local bx = next_inst >> 14
                local sbx = bx - 131071
                -- luac_obfuscate 的 JMP sBx = brush+1, brush=5-20, 所以 sBx=6-21
                if sbx >= 6 and sbx <= 21 then
                    -- 检查 JMP 目标是否在代码范围内
                    local jmp_target = i + 1 + sbx + 1
                    if jmp_target <= #p.code + 1 then
                        local junk_start = i + 2
                        local junk_len = sbx - 1
                    -- 检查是否是逻辑指令（有两个 JMP）
                    local is_logical = LOGICAL_OPS[op] ~= nil
                    if is_logical then
                        -- 逻辑指令: 原始 + JMP1 + JMP2 + 垃圾(sbx-2 条)
                        -- JMP1 的 sBx 应该也是 6-21, A=0
                        if junk_start <= #p.code then
                            local jmp2 = p.code[junk_start]
                            local jmp2_op = jmp2 % 64
                            local jmp2_a = (jmp2 >> 6) & 0xFF
                            if jmp2_op == 30 and jmp2_a == 0 then
                                local bx2 = jmp2 >> 14
                                local sbx2 = bx2 - 131071
                                if sbx2 >= 6 and sbx2 <= 21 then
                                    -- 确认是逻辑指令模式
                                    local actual_junk_start = junk_start + 1
                                    local actual_junk_len = sbx2 - 1
                                    if is_junk_block(p.code, actual_junk_start, actual_junk_len, #p.k) then
                                        -- 移除 JMP1 + JMP2 + 垃圾
                                        local remove_len = 2 + actual_junk_len
                                        adjust_jumps_remove(p.code, i + 1, remove_len)
                                        for j = 1, remove_len do
                                            table.remove(p.code, i + 1)
                                        end
                                        removed = removed + remove_len
                                    end
                                end
                            end
                        end
                    else
                        -- 非逻辑指令: 原始 + JMP + 随机指令 + 垃圾(sbx-2 条)
                        -- 检查垃圾块
                        if is_junk_block(p.code, junk_start, junk_len, #p.k) then
                            local remove_len = 1 + junk_len  -- JMP + 垃圾
                            adjust_jumps_remove(p.code, i + 1, remove_len)
                            for j = 1, remove_len do
                                table.remove(p.code, i + 1)
                            end
                            removed = removed + remove_len
                        end
                    end
                    end  -- if jmp_target
                end
            end
            i = i + 1
        else
            i = i + 1
        end
    end
    return removed
end

function de_junk_obfuscate.remove(proto, options)
    options = options or {}
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    local total = remove_in_func(proto)

    if recursive then
        for i = 1, #proto.p do
            total = total + de_junk_obfuscate.remove(proto.p[i], options)
        end
    end

    return total
end

-- CLI
if arg and arg[0] and arg[0]:match("de_junk_obfuscate") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_dejunk.lua")

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    local p = luac.undump(data, false)
    local removed = de_junk_obfuscate.remove(p)
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Removed " .. removed .. " junk instructions from luac_obfuscate")
    local ok = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return de_junk_obfuscate
