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
    local dangerous_ops = 0  -- RETURN/CALL/TAILCALL/CLOSURE 等重要指令
    for i = pos, pos + n - 1 do
        local inst = code[i]
        local op = inst % 64
        local a = (inst >> 6) & 0xFF
        local b = (inst >> 23) & 0x1FF
        local c = (inst >> 14) & 0x1FF

        -- 无效操作码 (>46)
        if op > 46 then invalid_op_count = invalid_op_count + 1 end
        -- 高寄存器 (>= 100)
        if a >= 100 then high_reg_count = high_reg_count + 1 end
        if b < 256 and b >= 100 then high_reg_count = high_reg_count + 1 end
        if c < 256 and c >= 100 then high_reg_count = high_reg_count + 1 end
        -- 常量索引超出范围
        if op == 1 and b >= num_consts then bad_const_count = bad_const_count + 1 end
        if b >= 256 and (b - 256) >= num_consts then bad_const_count = bad_const_count + 1 end
        if c >= 256 and (c - 256) >= num_consts then bad_const_count = bad_const_count + 1 end
        -- 危险指令（真实代码中常见，垃圾中出现概率低）
        if op == 36 or op == 37 or op == 38 or op == 44 then
            dangerous_ops = dangerous_ops + 1
        end
    end
    -- 严格判断: 无效操作码 >= 25% 且 危险指令 <= 10%
    local invalid_ratio = invalid_op_count / n
    local dangerous_ratio = dangerous_ops / n
    if invalid_ratio >= 0.25 and dangerous_ratio <= 0.10 then
        return true
    end
    -- 备选: 无效操作码 >= 15% 且 高寄存器 >= 40% 且 坏常量 >= 15%
    local high_reg_ratio = high_reg_count / (n * 3)
    local bad_const_ratio = bad_const_count / n
    if invalid_ratio >= 0.15 and high_reg_ratio >= 0.40 and bad_const_ratio >= 0.15 then
        return true
    end
    return false
end

local function remove_in_func(p)
    local n = #p.code
    if n < 2 then return 0 end

    -- 第一步: 贪心扫描, 标记哪些指令保留, 哪些移除
    local keep = {}
    local remove_blocks = {}  -- {{start, length}, ...}
    local i = 1
    while i <= n do
        keep[i] = true
        -- 检查下一条是否是注入的 JMP: A=0, sBx=6-21
        if i + 1 <= n then
            local jmp_inst = p.code[i + 1]
            local jmp_op = jmp_inst % 64
            local jmp_a = (jmp_inst >> 6) & 0xFF
            if jmp_op == 30 and jmp_a == 0 then
                local bx = jmp_inst >> 14
                local sbx = bx - 131071
                if sbx >= 6 and sbx <= 21 then
                    local junk_start = i + 2
                    local junk_end = i + 1 + sbx  -- JMP 跳过 sbx 条
                    if junk_end <= n then
                        local junk_len = sbx
                        -- 检查是否是垃圾块
                        if is_junk_block(p.code, junk_start, junk_len, #p.k) then
                            -- 标记移除
                            table.insert(remove_blocks, {start = i + 1, length = 1 + junk_len})
                            i = junk_end + 1  -- 跳到下一个原始指令
                            goto continue
                        end
                    end
                end
            end
        end
        i = i + 1
        ::continue::
    end

    if #remove_blocks == 0 then return 0 end

    -- 第二步: 从后往前移除, 调整跳转偏移
    local total_removed = 0
    for idx = #remove_blocks, 1, -1 do
        local block = remove_blocks[idx]
        adjust_jumps_remove(p.code, block.start, block.length)
        for j = 1, block.length do
            table.remove(p.code, block.start)
        end
        total_removed = total_removed + block.length
    end

    return total_removed
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
