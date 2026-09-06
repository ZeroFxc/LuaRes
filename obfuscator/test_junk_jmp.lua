local luac = require("luac")
local junk_jmp = require("junk_jmp")

-- 测试1: hello world
print("=== Test 1: hello world ===")
local func = load("print('hello world')")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)
junk_jmp.inject(p, {count = 30})
local out = luac.dump(p)
print("Size: " .. #bc .. " -> " .. #out)
local ok, f = pcall(load, out)
print("Load: " .. tostring(ok))
if ok then f() end

-- 测试2: 多子函数脚本
print("\n=== Test 2: multi-function ===")
local func2 = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc2 = string.dec(string.dump(func2))
local p2 = luac.undump(bc2, false)
junk_jmp.inject(p2, {count = 50})
local out2 = luac.dump(p2)
print("Size: " .. #bc2 .. " -> " .. #out2)

-- 统计 JMP 数量
local p3 = luac.undump(out2, false)
local jmp_count = 0
local total = 0
local function count(pp)
    for i = 1, #pp.code do
        total = total + 1
        if pp.code[i] % 64 == 30 then
            local bx = pp.code[i] >> 14
            local sbx = bx - 131071
            if sbx == 0 then jmp_count = jmp_count + 1 end
        end
    end
    for i = 1, #pp.p do count(pp.p[i]) end
end
count(p3)
print("Junk JMP (sBx=0): " .. jmp_count .. " / " .. total .. " instructions")

local ok2, f2 = pcall(load, out2)
print("Load: " .. tostring(ok2))
if ok2 then
    local outputs = {}
    local old_print = print
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok = pcall(f2)
    print = old_print
    print("Execute: " .. tostring(exec_ok))
    print("Last output: " .. outputs[#outputs])
    print("Output count: " .. #outputs)
end

-- 测试3: 复杂脚本（循环+条件+递归）
print("\n=== Test 3: complex script ===")
local complex = [[
local function fib(n)
    if n <= 1 then return n end
    return fib(n-1) + fib(n-2)
end
local sum = 0
for i = 1, 20 do
    sum = sum + fib(i)
end
if sum > 1000 then
    print("large: " .. sum)
else
    print("small: " .. sum)
end
print("done")
]]
local func3 = load(complex)
local bc3 = string.dec(string.dump(func3))
local p4 = luac.undump(bc3, false)
junk_jmp.inject(p4, {count = 80})
local out3 = luac.dump(p4)
print("Size: " .. #bc3 .. " -> " .. #out3)
local ok3, f3 = pcall(load, out3)
print("Load: " .. tostring(ok3))
if ok3 then
    local outputs = {}
    local old_print = print
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok = pcall(f3)
    print = old_print
    print("Execute: " .. tostring(exec_ok))
    print("Outputs: " .. table.concat(outputs, ", "))
end
