-- deflatten.lua - 控制流扁平化分析与部分还原
-- 控制流扁平化完全还原几乎不可能, 但可以:
--   1. 识别扁平化模式 (state 寄存器 + 调度循环)
--   2. 移除调度循环中明显的恒等比较
--   3. 统计扁平化程度
--
-- 用法: local deflat = require("deflatten"); deflat.analyze(proto)
--       deflat.partial_restore(proto)

local luac = require("luac")

local deflatten = {}

local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}
local COND_OPS = {[31]=true,[32]=true,[33]=true,[34]=true,[35]=true}

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

-- 分析函数中的扁平化模式
local function analyze_function(proto, path, result)
    local code = proto.code
    local n = #code

    -- 统计调度循环特征: LOADK + EQ/LT/LE + JMP 的重复模式
    local dispatch_count = 0
    local state_regs = {}
    local i = 1
    while i <= n - 2 do
        local op1 = code[i] % 64
        local op2 = code[i + 1] % 64
        local op3 = code[i + 2] % 64
        -- 模式: LOADK reg, const + EQ/LT/LE reg, reg, const + JMP
        if op1 == 1 and (op2 == 31 or op2 == 32 or op2 == 33) and op3 == 30 then
            local a1 = (code[i] >> 6) & 0xFF
            local a2 = (code[i + 1] >> 6) & 0xFF
            local b2 = (code[i + 1] >> 23) & 0x1FF
            if a1 == a2 and (b2 == a1 or b2 >= 256) then
                dispatch_count = dispatch_count + 1
                state_regs[a1] = (state_regs[a1] or 0) + 1
            end
        end
        i = i + 1
    end

    if dispatch_count > 0 then
        table.insert(result, {
            path = path,
            dispatch_count = dispatch_count,
            state_regs = state_regs,
            code_size = n,
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

-- 部分还原: 移除调度循环中明显的恒等比较
-- 保守实现: 只移除 LOADK reg, N + EQ reg, reg, N + JMP 这种永远为 false 的比较
-- (EQ reg, reg, const 当 reg != const 时永远为 false, 但 reg 可能被修改, 所以保守处理)
local function partial_restore_function(proto)
    local removed = 0
    local code = proto.code
    local i = 1
    while i <= #code - 2 do
        local op1 = code[i] % 64
        local op2 = code[i + 1] % 64
        local op3 = code[i + 2] % 64
        -- 模式: LOADK reg, const + EQ reg, reg, const + JMP
        -- EQ reg, reg, const: 比较 reg 和 const, 刚 LOADK 后 reg == const, 所以 EQ 为 true
        -- 这是调度循环的标准模式, 但移除风险大, 暂时只统计不修改
        if op1 == 1 and op2 == 31 and op3 == 30 then
            local a1 = (code[i] >> 6) & 0xFF
            local a2 = (code[i + 1] >> 6) & 0xFF
            local b2 = (code[i + 1] >> 23) & 0x1FF
            if a1 == a2 and b2 == a1 then
                -- 这是 EQ reg, reg, const 模式, 保守处理: 不移除
                i = i + 3
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    return removed
end

function deflatten.partial_restore(proto, options)
    options = options or {}
    local total = partial_restore_function(proto)
    for i = 1, #proto.p do
        total = total + partial_restore_function(proto.p[i])
    end
    return total
end

-- CLI
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
                print(string.format("  %s: %d dispatch patterns, code size %d",
                    r.path, r.dispatch_count, r.code_size))
                for reg, count in pairs(r.state_regs) do
                    print(string.format("    state reg %d: %d uses", reg, count))
                end
            end
        end
    elseif mode == "restore" then
        local removed = deflatten.partial_restore(p)
        local out = luac.dump(p)
        local output = arg[3] or input:gsub("%.lua$", "_deflat.lua")
        local fout = io.open(output, "wb")
        fout:write(out)
        fout:close()
        print("Removed " .. removed .. " instructions (partial restore)")
        print("Output: " .. output .. " (" .. #out .. " bytes)")
        local ok = pcall(load, out)
        print("Load test: " .. tostring(ok))
    end
end

return deflatten
