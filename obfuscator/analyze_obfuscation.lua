-- analyze_obfuscation.lua - analyze obfuscated bytecode to identify patterns
local luac = require("luac")

local input_path = arg[1] or "E:/LuaRes/layout.lua"

local f = io.open(input_path, "rb")
if not f then print("cannot open " .. input_path); os.exit(1) end
local data = f:read("*a")
f:close()

print("========================================")
print("  Obfuscation Analyzer: " .. input_path)
print("========================================")
print("Size: " .. #data .. " bytes")

local proto = luac.undump(data, false)

-- Collect stats
local total_funcs = 0
local total_code = 0
local total_k = 0
local opcode_counts = {}
local jmp_patterns = {}  -- count JMP with small sBx
local short_jmps = 0
local logical_ops = 0
local random_looking = 0

local OP_NAMES = luac.OPCODE_NAMES

local function analyze(p, depth)
    total_funcs = total_funcs + 1
    total_code = total_code + #p.code
    total_k = total_k + #p.k

    local code = p.code
    for i = 1, #code do
        local ins = code[i]
        local op = luac.GET_OPCODE(ins)
        opcode_counts[op] = (opcode_counts[op] or 0) + 1

        -- Check for short JMPs (garbage skippers)
        if op == luac.OP_JMP then
            local sbx = luac.GETARG_sBx(ins)
            if sbx > 0 and sbx <= 30 then
                short_jmps = short_jmps + 1
                jmp_patterns[sbx] = (jmp_patterns[sbx] or 0) + 1
            end
        end

        -- Logical ops (EQ/LT/LE/TEST/TESTSET/LOADBOOL)
        if op == luac.OP_EQ or op == luac.OP_LT or op == luac.OP_LE
           or op == luac.OP_TEST or op == luac.OP_TESTSET or op == luac.OP_LOADBOOL then
            logical_ops = logical_ops + 1
        end
    end

    for i = 1, #p.p do
        analyze(p.p[i], depth + 1)
    end
end

analyze(proto, 0)

print(string.format("\nFunctions: %d", total_funcs))
print(string.format("Total instructions: %d", total_code))
print(string.format("Total constants: %d", total_k))
print(string.format("Avg instructions/function: %.1f", total_code / total_funcs))

-- Top opcodes
print("\n=== Top 20 Opcodes ===")
local sorted = {}
for op, count in pairs(opcode_counts) do
    table.insert(sorted, {op = op, count = count, name = OP_NAMES[op + 1] or ("OP_" .. op)})
end
table.sort(sorted, function(a, b) return a.count > b.count end)
for i = 1, math.min(20, #sorted) do
    local pct = sorted[i].count / total_code * 100
    print(string.format("  %2d. %-12s %8d  (%5.1f%%)", i, sorted[i].name, sorted[i].count, pct))
end

-- JMP analysis
print("\n=== JMP Analysis ===")
print(string.format("Short JMPs (sBx 1-30): %d (%.1f%% of all)", short_jmps, short_jmps / total_code * 100))
print("JMP sBx distribution:")
local sorted_jmp = {}
for sbx, count in pairs(jmp_patterns) do
    table.insert(sorted_jmp, {sbx = sbx, count = count})
end
table.sort(sorted_jmp, function(a, b) return a.count > b.count end)
for i = 1, math.min(15, #sorted_jmp) do
    print(string.format("  sBx=%2d: %d times", sorted_jmp[i].sbx, sorted_jmp[i].count))
end

-- Logical ops
print(string.format("\nLogical ops (EQ/LT/LE/TEST/TESTSET/LOADBOOL): %d (%.1f%%)",
    logical_ops, logical_ops / total_code * 100))

-- Pattern detection: look for JMP + non-JMP + JMP sequences (obfuscate pattern)
print("\n=== Pattern Detection ===")
local function detect_patterns(p)
    local code = p.code
    local jmp_then_jmp = 0  -- JMP followed by JMP (logical op pattern)
    local jmp_then_random = 0  -- JMP followed by non-control-flow
    for i = 1, #code - 1 do
        local op1 = luac.GET_OPCODE(code[i])
        local op2 = luac.GET_OPCODE(code[i + 1])
        if op1 == luac.OP_JMP and op2 == luac.OP_JMP then
            jmp_then_jmp = jmp_then_jmp + 1
        end
        if op1 == luac.OP_JMP and op2 ~= luac.OP_JMP and op2 ~= luac.OP_RETURN then
            jmp_then_random = jmp_then_random + 1
        end
    end
    for i = 1, #p.p do
        local sub = detect_patterns(p.p[i])
        jmp_then_jmp = jmp_then_jmp + sub.jmp_then_jmp
        jmp_then_random = jmp_then_random + sub.jmp_then_random
    end
    return {jmp_then_jmp = jmp_then_jmp, jmp_then_random = jmp_then_random}
end
local patterns = detect_patterns(proto)
print(string.format("JMP followed by JMP: %d (logical obfuscation indicator)", patterns.jmp_then_jmp))
print(string.format("JMP followed by non-jmp: %d", patterns.jmp_then_random))

-- Check for high JMP ratio (obfuscation indicator)
local jmp_count = opcode_counts[luac.OP_JMP] or 0
print(string.format("\nJMP ratio: %.1f%% (normal code ~2-5%%, obfuscated >15%%)", jmp_count / total_code * 100))

print("\nDone.")
