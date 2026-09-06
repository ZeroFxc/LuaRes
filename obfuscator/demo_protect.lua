-- demo_protect.lua - demonstrate protect pipeline on a real-world bytecode
local luac = require("luac")
local protect = require("protect")

local input_path = arg[1] or "E:/LuaRes/main.lua"
local output_path = arg[2] or "E:/LuaRes/main_protected.luac"

-- Read input
local f = io.open(input_path, "rb")
if not f then print("cannot open " .. input_path); os.exit(1) end
local data = f:read("*a")
f:close()

print("========================================")
print("  Bytecode Protection Demo")
print("========================================")
print("Input: " .. input_path)
print("Original size: " .. #data .. " bytes")

-- Parse original stats
local proto = luac.undump(data, false)
local function count_stats(p, depth)
    local stats = {funcs = 1, code = #p.code, k = #p.k, p = #p.p}
    for i = 1, #p.p do
        local sub = count_stats(p.p[i], depth + 1)
        stats.funcs = stats.funcs + sub.funcs
        stats.code = stats.code + sub.code
        stats.k = stats.k + sub.k
    end
    return stats
end
local orig_stats = count_stats(proto, 0)
print(string.format("Functions: %d, Total instructions: %d, Total constants: %d",
    orig_stats.funcs, orig_stats.code, orig_stats.k))

-- Protect
print("\nApplying protection pipeline...")
math.randomseed(os.time())
local protected, stats = protect(data, {})
print("Passes: " .. table.concat(stats.passes, " -> "))

-- Parse protected stats
local prot_proto = luac.undump(protected, false)
local prot_stats = count_stats(prot_proto, 0)

-- Write output
f = io.open(output_path, "wb")
f:write(protected)
f:close()

print("\n========================================")
print("  Results")
print("========================================")
print(string.format("  Size:           %d -> %d bytes (%s)",
    #data, #protected, stats.ratio))
print(string.format("  Functions:      %d (unchanged)", prot_stats.funcs))
print(string.format("  Instructions:   %d -> %d (%.1f%%)",
    orig_stats.code, prot_stats.code, prot_stats.code / orig_stats.code * 100))
print(string.format("  Constants:      %d -> %d",
    orig_stats.k, prot_stats.k))
print("  Output: " .. output_path)

-- Verify load
print("\nVerifying protected bytecode loads...")
local ok, func = pcall(load, protected)
if ok and func then
    print("  [PASS] Protected bytecode loads successfully")
else
    print("  [FAIL] Load failed: " .. tostring(func))
end

-- Verify original loads too
local ok2, func2 = pcall(load, data)
print("  Original loads: " .. (ok2 and "yes" or "no"))

print("\nDone.")
