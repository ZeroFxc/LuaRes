local num_obf = require('num_obfuscate')
local luac = require('luac')

-- 测试1: 简单数字
print('=== Test 1: simple numbers ===')
local func = load('local a = 42; local b = 100; local c = 7; return a + b * c')
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('Original constants:')
for i = 1, #proto.k do
    print('  [' .. i .. ']', type(proto.k[i]), tostring(proto.k[i]))
end

math.randomseed(42)
local n = num_obf.obfuscate(proto, {rate = 1.0})
print('Obfuscated', n, 'number references')

print('Obfuscated constants:')
for i = 1, #proto.k do
    print('  [' .. i .. ']', type(proto.k[i]), tostring(proto.k[i]))
end

local enc_bc = luac.dump(proto)
local f = load(enc_bc)
print('Result:', f(), '(expected: 742)')

-- 测试2: 各种数字
print()
print('=== Test 2: various numbers ===')
local func2 = load([[
local a = 1
local b = 2
local c = 3
local d = 10
local e = 100
local f = 255
local g = 1000
return a + b + c + d + e + f + g
]])
local bc2 = string.dec(string.dump(func2))
local proto2 = luac.undump(bc2, false)

math.randomseed(123)
num_obf.obfuscate(proto2, {rate = 0.8})
local enc_bc2 = luac.dump(proto2)
local f2 = load(enc_bc2)
print('Result:', f2(), '(expected: 1371)')

-- 测试3: 有字符串和数字混合
print()
print('=== Test 3: mixed strings and numbers ===')
local func3 = load([[
local s = "hello"
local n = 42
return s .. " " .. n
]])
local bc3 = string.dec(string.dump(func3))
local proto3 = luac.undump(bc3, false)

math.randomseed(456)
num_obf.obfuscate(proto3, {rate = 1.0})
local enc_bc3 = luac.dump(proto3)
local f3 = load(enc_bc3)
print('Result:', f3(), '(expected: hello 42)')

-- 测试4: 子函数中的数字
print()
print('=== Test 4: numbers in nested functions ===')
local func4 = load([[
local function add(a, b)
    return a + b + 100
end
local function mul(a, b)
    return a * b * 2
end
return add(3, 4) + mul(5, 6)
]])
local bc4 = string.dec(string.dump(func4))
local proto4 = luac.undump(bc4, false)

math.randomseed(789)
num_obf.obfuscate(proto4, {rate = 1.0})
local enc_bc4 = luac.dump(proto4)
local f4 = load(enc_bc4)
print('Result:', f4(), '(expected: 107 + 60 = 167)')

print()
print('All tests done!')
