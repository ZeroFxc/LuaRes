local luac = require("luac")
local anti_td = require("anti_td")
local junk_loadk = require("junk_loadk")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))

-- 只 anti_td
local p1 = luac.undump(bc, false)
anti_td.protect(p1)
print("After anti_td:")
print("  main maxstack: " .. p1.maxstacksize .. ", sizeupvalues: " .. #p1.upvalues)
for i = 1, #p1.p do
    print(string.format("  p[%d] maxstack: %d, code: %d", i, p1.p[i].maxstacksize, #p1.p[i].code))
end

-- anti_td + junk_loadk (只 main，不递归)
local p2 = luac.undump(bc, false)
anti_td.protect(p2)
junk_loadk.inject(p2, {count = 10, recursive = false})
print("\nAfter anti_td + junk_loadk (main only):")
print("  main maxstack: " .. p2.maxstacksize .. ", code: " .. #p2.code)
for i = 1, #p2.p do
    print(string.format("  p[%d] maxstack: %d, code: %d", i, p2.p[i].maxstacksize, #p2.p[i].code))
end

local out = luac.dump(p2)
local ok, f = pcall(load, out)
print("\nLoad: " .. tostring(ok))
if ok then
    print("Execute:")
    f()
else
    print("Error: " .. tostring(f))
end
