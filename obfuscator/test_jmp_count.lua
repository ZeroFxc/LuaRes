local luac = require("luac")
local junk_jmp = require("junk_jmp")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))

-- 测试1: 只在 fib 注入 count=25
print("=== Test 1: fib only, count=25 ===")
local p1 = luac.undump(bc, false)
junk_jmp.inject(p1.p[3], {count = 25, recursive = false})
local out1 = luac.dump(p1)
local ok1, f1 = pcall(load, out1)
print("Load: " .. tostring(ok1))
if ok1 then
    local outputs = {}
    local old_print = print
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok = pcall(f1)
    print = old_print
    print("Execute: " .. tostring(exec_ok))
    print("Last: " .. outputs[#outputs])
else
    print("Error: " .. tostring(f1))
end

-- 测试2: 全函数 count=25
print("\n=== Test 2: all functions, count=25 ===")
local p2 = luac.undump(bc, false)
junk_jmp.inject(p2, {count = 25})
local out2 = luac.dump(p2)
local ok2, f2 = pcall(load, out2)
print("Load: " .. tostring(ok2))
if ok2 then
    local outputs = {}
    local old_print = print
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok, exec_err = pcall(f2)
    print = old_print
    print("Execute: " .. tostring(exec_ok))
    if not exec_ok then
        print("Error: " .. tostring(exec_err))
    else
        print("Last: " .. outputs[#outputs])
        print("Count: " .. #outputs)
    end
else
    print("Error: " .. tostring(f2))
end

-- 测试3: 全函数 count=10
print("\n=== Test 3: all functions, count=10 ===")
local p3 = luac.undump(bc, false)
junk_jmp.inject(p3, {count = 10})
local out3 = luac.dump(p3)
local ok3, f3 = pcall(load, out3)
print("Load: " .. tostring(ok3))
if ok3 then
    local outputs = {}
    local old_print = print
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok, exec_err = pcall(f3)
    print = old_print
    print("Execute: " .. tostring(exec_ok))
    if not exec_ok then
        print("Error: " .. tostring(exec_err))
    else
        print("Last: " .. outputs[#outputs])
    end
else
    print("Error: " .. tostring(f3))
end
