local luac = require("luac")
local opaque_junk = require("opaque_junk")

-- Test 1: hello world
print("=== Test 1: hello world ===")
local func1 = load("print('hello world')")
local bc1 = string.dec(string.dump(func1))
local p1 = luac.undump(bc1, false)
opaque_junk.inject(p1, {count = 5})
local out1 = luac.dump(p1)
print("Size: " .. #bc1 .. " -> " .. #out1)
local ok1, f1 = pcall(load, out1)
print("Load: " .. tostring(ok1))
if ok1 then f1() end

-- Test 2: multi-function
print("\n=== Test 2: multi-function ===")
local func2 = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc2 = string.dec(string.dump(func2))
local p2 = luac.undump(bc2, false)
opaque_junk.inject(p2, {count = 10})
local out2 = luac.dump(p2)
print("Size: " .. #bc2 .. " -> " .. #out2)
local ok2, f2 = pcall(load, out2)
print("Load: " .. tostring(ok2))
if ok2 then
    local outputs = {}
    local old_print = print
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok, err = pcall(f2)
    print = old_print
    print("Execute: " .. tostring(exec_ok))
    if not exec_ok then print("Error: " .. tostring(err)) end
    print("Last: " .. outputs[#outputs])
end

-- Test 3: stress
print("\n=== Test 3: stress (10 trials) ===")
local passed = 0
for trial = 1, 10 do
    local p = luac.undump(bc2, false)
    opaque_junk.inject(p, {count = 10})
    local out = luac.dump(p)
    local ok, f = pcall(load, out)
    local exec_ok = false
    if ok then
        local old_print = print
        print = function() end
        exec_ok = pcall(f)
        print = old_print
    end
    if exec_ok then passed = passed + 1 end
end
print("Passed: " .. passed .. "/10")
