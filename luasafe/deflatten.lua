-- deflatten.lua - 控制流扁平化分析与还原
-- 算法: dispatcher检测 -> 状态变量识别 -> 状态转移图构建 -> CFG重建
--
-- 扁平化模式(Lua字节码, luac_flatten风格):
--   入口: LOADK state_reg, init_state
--   dispatch: EQ state_reg, Kst(val1) + JMP block1
--             EQ state_reg, Kst(val2) + JMP block2
--             ...
--   基本块: ...代码...
--             LOADK state_reg, next_state
--             JMP dispatch
--
-- 也支持OLLVM风格: LOADK tmp, val + EQ state_reg, tmp + JMP block
--
-- 还原:
--   1. 识别dispatch块(连续的EQ+JMP比较链)
--   2. 识别状态寄存器(dispatch中被EQ比较的寄存器)
--   3. 构建 state_value(const_idx) -> 基本块起始位置 映射
--   4. 每个基本块末尾的 LOADK state + JMP dispatch 替换为直接 JMP 目标块
--   5. 删除dispatch块中的比较链和入口的初始状态赋值
--
-- 用法: local deflat = require("deflatten")
--       deflat.analyze(proto)     -- 只分析
--       deflat.restore(proto)      -- 还原控制流

local luac = require("luac")

local deflatten = {}

local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}
local COND_OPS = {[31]=true,[32]=true,[33]=true,[34]=true,[35]=true}

-- ============================================================
-- 基本块识别
-- ============================================================
local function build_basic_blocks(code)
    local leaders = {}
    leaders[1] = true
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            local target = i + sbx + 1
            if target >= 1 and target <= #code then
                leaders[target] = true
            end
            if i + 1 <= #code then
                leaders[i + 1] = true
            end
        elseif COND_OPS[op] then
            if i + 2 <= #code then
                leaders[i + 2] = true
            end
        elseif op == 38 then
            if i + 1 <= #code then
                leaders[i + 1] = true
            end
        end
    end

    local blocks = {}
    local sorted_leaders = {}
    for pos in pairs(leaders) do
        table.insert(sorted_leaders, pos)
    end
    table.sort(sorted_leaders)

    for idx, start in ipairs(sorted_leaders) do
        local end_pos = (sorted_leaders[idx + 1] or (#code + 1)) - 1
        table.insert(blocks, {start = start, stop = end_pos})
    end
    return blocks
end

-- ============================================================
-- Dispatcher检测: 直接扫描整个指令序列, 找到最长的连续比较链
-- 支持两种模式:
--   模式A(luac_flatten): EQ state_reg, Kst(val) + JMP target
--   模式B(OLLVM): LOADK tmp, val + EQ state_reg, tmp + JMP target
-- ============================================================
local function find_dispatcher(code, blocks)
    local best_start = 0
    local best_stop = 0
    local best_score = 0
    local best_state_reg = nil
    local best_mode = nil

    -- 扫描模式A: 连续的 EQ+JMP
    local i = 1
    while i <= #code - 1 do
        local chain_start = i
        local chain_len = 0
        local state_reg = nil
        local j = i
        while j <= #code - 1 do
            local op1 = code[j] % 64
            local op2 = code[j + 1] % 64
            if op1 == 31 and op2 == 30 then
                local b1 = (code[j] >> 23) & 0x1FF
                local c1 = (code[j] >> 14) & 0x1FF
                if b1 < 256 and c1 >= 256 then
                    if state_reg == nil then
                        state_reg = b1
                    elseif state_reg ~= b1 then
                        break
                    end
                    chain_len = chain_len + 1
                    j = j + 2
                else
                    break
                end
            else
                break
            end
        end
        if chain_len >= 2 then
            local score = chain_len * 2
            if score > best_score then
                best_score = score
                best_start = chain_start
                best_stop = j - 1
                best_state_reg = state_reg
                best_mode = "A"
            end
        end
        i = i + 1
    end

    -- 扫描模式B: 连续的 LOADK+EQ+JMP
    i = 1
    while i <= #code - 2 do
        local chain_start = i
        local chain_len = 0
        local state_reg = nil
        local j = i
        while j <= #code - 2 do
            local op1 = code[j] % 64
            local op2 = code[j + 1] % 64
            local op3 = code[j + 2] % 64
            if op1 == 1 and op2 == 31 and op3 == 30 then
                local a1 = (code[j] >> 6) & 0xFF
                local b2 = (code[j + 1] >> 23) & 0x1FF
                local c2 = (code[j + 1] >> 14) & 0x1FF
                if b2 < 256 and c2 == a1 then
                    if state_reg == nil then
                        state_reg = b2
                    elseif state_reg ~= b2 then
                        break
                    end
                    chain_len = chain_len + 1
                    j = j + 3
                else
                    break
                end
            else
                break
            end
        end
        if chain_len >= 2 then
            local score = chain_len * 3
            if score > best_score then
                best_score = score
                best_start = chain_start
                best_stop = j - 1
                best_state_reg = state_reg
                best_mode = "B"
            end
        end
        i = i + 1
    end

    if best_score == 0 then
        return nil, nil, 0, nil
    end

    -- 构造dispatch块
    local dispatch_block = {start = best_start, stop = best_stop}
    return dispatch_block, best_state_reg, best_score, best_mode
end

-- ============================================================
-- 构建 state_value -> 基本块起始位置 映射
-- state_value 是常量索引(Bx for LOADK, C-256 for EQ Kst)
-- ============================================================
local function build_state_map(code, dispatch_block, state_reg, mode)
    local state_map = {}
    local i = dispatch_block.start

    while i <= dispatch_block.stop - 1 do
        local op1 = code[i] % 64

        if mode == "A" and op1 == 31 and i + 1 <= dispatch_block.stop then
            -- 模式A: EQ state_reg, Kst(val) + JMP target
            local op2 = code[i + 1] % 64
            if op2 == 30 then
                local b1 = (code[i] >> 23) & 0x1FF
                local c1 = (code[i] >> 14) & 0x1FF
                if b1 == state_reg and c1 >= 256 then
                    local const_idx = c1 - 256
                    local bx2 = code[i + 1] >> 14
                    local sbx2 = bx2 - 131071
                    local target = i + 1 + sbx2 + 1
                    state_map[const_idx] = target
                end
                i = i + 2
            else
                i = i + 1
            end
        elseif mode == "B" and op1 == 1 and i + 2 <= dispatch_block.stop then
            -- 模式B: LOADK tmp, val + EQ state_reg, tmp + JMP target
            local op2 = code[i + 1] % 64
            local op3 = code[i + 2] % 64
            if op2 == 31 and op3 == 30 then
                local a1 = (code[i] >> 6) & 0xFF
                local bx1 = code[i] >> 14
                local b2 = (code[i + 1] >> 23) & 0x1FF
                local c2 = (code[i + 1] >> 14) & 0x1FF
                if b2 == state_reg and c2 == a1 then
                    local bx3 = code[i + 2] >> 14
                    local sbx3 = bx3 - 131071
                    local target = i + 2 + sbx3 + 1
                    state_map[bx1] = target
                end
                i = i + 3
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    return state_map
end

-- ============================================================
-- 调整跳转偏移(删除指令后)
-- ============================================================
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

-- ============================================================
-- 还原单个函数的控制流
-- ============================================================
local function restore_function(proto)
    local code = proto.code
    if #code < 10 then return 0 end

    local blocks = build_basic_blocks(code)
    local dispatch_block, state_reg, score, mode = find_dispatcher(code, blocks)

    if not dispatch_block or not state_reg or score < 4 then
        return 0
    end

    local state_map = build_state_map(code, dispatch_block, state_reg, mode)
    if not next(state_map) then
        return 0
    end

    -- dispatch块的起始位置
    local dispatch_start = dispatch_block.start
    -- dispatch块中第一条比较指令的位置
    local first_compare = dispatch_start
    local i = dispatch_start
    while i <= dispatch_block.stop do
        local op = code[i] % 64
        if op == 31 or (op == 1 and i + 2 <= dispatch_block.stop and code[i+1]%64 == 31) then
            first_compare = i
            break
        end
        i = i + 1
    end

    -- 步骤1: 收集所有需要替换的 JMP dispatch 位置和目标状态(不修改代码)
    local replacements = {}  -- {jmp_pos, target_block}
    for _, blk in ipairs(blocks) do
        if blk.start ~= dispatch_start and blk.start >= first_compare then
            local j = blk.stop
            while j >= blk.start + 1 do
                local op_jmp = code[j] % 64
                if op_jmp == 30 then
                    local bx = code[j] >> 14
                    local sbx = bx - 131071
                    local target = j + sbx + 1
                    if target == first_compare or (target >= dispatch_block.start and target <= dispatch_block.stop) then
                        local op_load = code[j - 1] % 64
                        if op_load == 1 then
                            local a_load = (code[j - 1] >> 6) & 0xFF
                            local bx_load = code[j - 1] >> 14
                            if a_load == state_reg then
                                local target_block = state_map[bx_load]
                                if target_block then
                                    table.insert(replacements, {jmp_pos = j, load_pos = j - 1, target_block = target_block})
                                end
                            end
                        end
                    end
                end
                j = j - 1
            end
        end
    end

    if #replacements == 0 then
        return 0
    end

    -- 步骤2: 替换所有 JMP dispatch 为 JMP target_block(不删除任何指令)
    for _, r in ipairs(replacements) do
        local new_sbx = r.target_block - r.jmp_pos - 1
        local new_bx = new_sbx + 131071
        code[r.jmp_pos] = (code[r.jmp_pos] & 0x3FFF) | (new_bx << 14)
    end

    -- 步骤3: 标记所有需要删除的指令位置
    local to_remove = {}  -- 位置集合

    -- 3a: dispatch块中的比较链
    local j = dispatch_block.stop
    while j >= dispatch_block.start do
        local op1 = code[j] % 64
        if mode == "A" and op1 == 30 and j > dispatch_block.start then
            local op0 = code[j - 1] % 64
            if op0 == 31 then
                local b0 = (code[j - 1] >> 23) & 0x1FF
                if b0 == state_reg then
                    to_remove[j] = true
                    to_remove[j - 1] = true
                    j = j - 2
                else
                    j = j - 1
                end
            else
                j = j - 1
            end
        elseif mode == "B" and op1 == 30 and j > dispatch_block.start + 1 then
            local op0 = code[j - 1] % 64
            local op_1 = code[j - 2] % 64
            if op0 == 31 and op_1 == 1 then
                local b0 = (code[j - 1] >> 23) & 0x1FF
                local c0 = (code[j - 1] >> 14) & 0x1FF
                local a_1 = (code[j - 2] >> 6) & 0xFF
                if b0 == state_reg and c0 == a_1 then
                    to_remove[j] = true
                    to_remove[j - 1] = true
                    to_remove[j - 2] = true
                    j = j - 3
                else
                    j = j - 1
                end
            else
                j = j - 1
            end
        else
            j = j - 1
        end
    end

    -- 3b: 入口的初始 LOADK state_reg
    if dispatch_block.start > 1 then
        local entry_op = code[dispatch_block.start - 1] % 64
        if entry_op == 1 then
            local a_entry = (code[dispatch_block.start - 1] >> 6) & 0xFF
            if a_entry == state_reg then
                to_remove[dispatch_block.start - 1] = true
            end
        end
    end

    -- 3c: 基本块末尾的 LOADK state_reg -> 变成 JMP sBx=0(不删除, 防止条件分支JMP跳到无效位置)
    for _, r in ipairs(replacements) do
        -- JMP sBx=0: op=30, A=0, Bx=131071
        code[r.load_pos] = 30 | (131071 << 14)
    end

    -- 步骤4: 从后往前删除所有标记的指令(每次删除时调整JMP偏移)
    local remove_list = {}
    for pos in pairs(to_remove) do
        table.insert(remove_list, pos)
    end
    table.sort(remove_list, function(a, b) return a > b end)

    local removed = 0
    for _, pos in ipairs(remove_list) do
        adjust_jumps_remove(code, pos, 1)
        table.remove(code, pos)
        removed = removed + 1
    end

    return removed + #replacements
end

-- ============================================================
-- 分析函数中的扁平化模式
-- ============================================================
local function analyze_function(proto, path, result)
    local code = proto.code
    local blocks = build_basic_blocks(code)
    local dispatch_block, state_reg, score, mode = find_dispatcher(code, blocks)

    if dispatch_block and state_reg and score >= 4 then
        local state_map = build_state_map(code, dispatch_block, state_reg, mode)
        local num_states = 0
        for _ in pairs(state_map) do num_states = num_states + 1 end
        table.insert(result, {
            path = path,
            dispatch_start = dispatch_block.start,
            dispatch_stop = dispatch_block.stop,
            state_reg = state_reg,
            dispatch_score = score,
            mode = mode,
            num_states = num_states,
            code_size = #code,
            num_blocks = #blocks,
        })
    end

    for i = 1, #proto.p do
        analyze_function(proto.p[i], path .. "/" .. i, result)
    end
end

function deflatten.analyze(proto)
    local result = {}
    analyze_function(proto, "main", result)
    return result
end

-- ============================================================
-- 还原控制流(递归处理所有子函数, 多轮迭代)
-- ============================================================
function deflatten.restore(proto, options)
    options = options or {}
    local max_passes = options.max_passes or 5
    local total = 0

    for pass = 1, max_passes do
        local removed = restore_function(proto)
        total = total + removed
        if removed == 0 then break end
    end

    -- 递归处理子函数
    for i = 1, #proto.p do
        total = total + deflatten.restore(proto.p[i], options)
    end

    return total
end

-- 兼容旧接口
function deflatten.partial_restore(proto, options)
    return deflatten.restore(proto, options)
end

-- ============================================================
-- CLI
-- ============================================================
if arg and arg[0] and arg[0]:match("deflatten") and arg[1] then
    local input = arg[1]
    local mode = arg[2] or "analyze"

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    local p = luac.undump(data, false)

    if mode == "analyze" then
        local result = deflatten.analyze(p)
        print("Control flow flattening analysis:")
        if #result == 0 then
            print("  No flattening detected")
        else
            for _, r in ipairs(result) do
                print(string.format("  %s: dispatch=[%d-%d], state_reg=R%d, mode=%s, score=%d, %d states, %d blocks, %d instructions",
                    r.path, r.dispatch_start, r.dispatch_stop, r.state_reg,
                    r.mode or "?", r.dispatch_score, r.num_states, r.num_blocks, r.code_size))
            end
        end
    elseif mode == "restore" then
        local removed = deflatten.restore(p)
        local out = luac.dump(p)
        local output = arg[3] or input:gsub("%.lua$", "_deflat.lua")
        local fout = io.open(output, "wb")
        fout:write(out)
        fout:close()
        print("Removed/modified " .. removed .. " instructions")
        print("Output: " .. output .. " (" .. #out .. " bytes)")
        local ok = pcall(load, out)
        print("Load test: " .. tostring(ok))
    end
end

return deflatten
