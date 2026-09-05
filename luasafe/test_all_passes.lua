-- test_all_passes.lua - test all protection passes individually and combined
local luac = require("luac")

-- Test function with various features
local test_func = function(a, b, c)
    local x = 0
    local s = "hello world"
    if a > b then
        x = a + b
        s = s .. " plus"
    elseif a < b then
        x = a - b
        s = s .. " minus"
    else
        x = a * b
        s = s .. " equal"
    end
    if x > 10 then
        x = x + 100
    end
    for i = 1, c do
        x = x + i
    end
    return x, s
end

local bc = string.dec(string.dump(test_func))
print("Original size:", #bc, "bytes")

-- Expected results
local function check(name, bytecode)
    local func = load(bytecode)
    if not func then print("  [FAIL]", name, "- load failed"); return false end
    local r1, r2 = func(5, 3, 2)
    local e1, e2 = test_func(5, 3, 2)
    if r1 == e1 and r2 == e2 then
        print("  [PASS]", name, string.format("(%d bytes, result=%d, %s)", #bytecode, r1, r2))
        return true
    else
        print("  [FAIL]", name, string.format("expected (%s,%s) got (%s,%s)", tostring(e1), tostring(e2), tostring(r1), tostring(r2)))
        return false
    end
end

local function save(name, data)
    local f = io.open("test_" .. name .. ".luac", "wb")
    f:write(data); f:close()
end

print("\n=== Individual Passes ===")

-- 1. debug_strip
local proto = luac.undump(bc, true)
local strip = require("debug_strip")
-- debug_strip is a CLI script, use inline version
local function do_strip(p)
    p.lineinfo = {}; p.locvars = {}
    for i = 1, #p.upvalues do p.upvalues[i].name = "" end
    for i = 1, p.sizep do do_strip(p.p[i]) end
end
do_strip(proto)
local out = luac.dump(proto)
save("strip", out)
check("debug_strip", out)

-- 2. const_shuffle
os.execute("lua_luac.exe const_shuffle.lua test_strip.luac test_shuffle.luac >nul 2>&1")
local f = io.open("test_shuffle.luac", "rb"); local sh = f:read("*a"); f:close()
check("const_shuffle", sh)

-- 3. instruction_mutate
os.execute("lua_luac.exe instruction_mutate.lua test_shuffle.luac test_mutate.luac >nul 2>&1")
f = io.open("test_mutate.luac", "rb"); local mu = f:read("*a"); f:close()
check("instruction_mutate", mu)

-- 4. opaque_predicate
os.execute("lua_luac.exe opaque_predicate.lua test_mutate.luac test_opaque.luac >nul 2>&1")
f = io.open("test_opaque.luac", "rb"); local op = f:read("*a"); f:close()
check("opaque_predicate", op)

-- 5. flatten
os.execute("lua_luac.exe luac_flatten.lua test_opaque.luac test_flatten.luac >nul 2>&1")
f = io.open("test_flatten.luac", "rb"); local fl = f:read("*a"); f:close()
check("control_flow_flatten", fl)

-- 6. obfuscate
os.execute("lua_luac.exe luac_obfuscate.lua test_flatten.luac test_obfuscate.luac >nul 2>&1")
f = io.open("test_obfuscate.luac", "rb"); local ob = f:read("*a"); f:close()
check("junk_obfuscate", ob)

print("\n=== Combined Pipeline (protect.lua) ===")
local protect = require("protect")
local protected, stats = protect(bc)
save("protected", protected)
check("full_protect", protected)
print(string.format("  Size: %d -> %d bytes (%s)", stats.original_size, stats.protected_size, stats.ratio))
print("  Passes: " .. table.concat(stats.passes, " -> "))

print("\n=== Cleanup ===")
for _, name in ipairs({"strip","shuffle","mutate","opaque","flatten","obfuscate","protected"}) do
    os.remove("test_" .. name .. ".luac")
end
print("Done.")
