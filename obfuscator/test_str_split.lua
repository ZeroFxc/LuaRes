local str_split = require('str_split')
local luac = require('luac')

-- 测试1: 简单字符串
local src = 'print("hello world")'
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)
local n = str_split.obfuscate(proto)
print('test1 obfuscated refs:', n)
local enc = luac.dump(proto)
print('size:', #bc, '->', #enc)
local f = load(enc)
f()

-- 测试2: boolean.lua
print()
local src2 = io.open('../boolean.lua'):read('*a')
local func2 = load(src2)
local bc2 = string.dec(string.dump(func2))
local proto2 = luac.undump(bc2, false)
local n2 = str_split.obfuscate(proto2)
print('test2 boolean obfuscated refs:', n2)
local enc2 = luac.dump(proto2)
print('size:', #bc2, '->', #enc2)
local f2 = load(enc2)
f2()

-- 测试3: 嵌套函数 + 字符串
print()
local src3 = [[
local function greet(name)
    return "hello " .. name
end
print(greet("world"))
]]
local func3 = load(src3)
local bc3 = string.dec(string.dump(func3))
local proto3 = luac.undump(bc3, false)
local n3 = str_split.obfuscate(proto3)
print('test3 nested obfuscated refs:', n3)
local enc3 = luac.dump(proto3)
print('size:', #bc3, '->', #enc3)
local f3 = load(enc3)
f3()

print('\nAll tests passed!')
