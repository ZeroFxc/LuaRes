local str_encrypt = require('str_encrypt')
local luac = require('luac')

-- 测试1: 简单字符串
print('=== Test 1: simple string ===')
local func = load('local s = "hello world"; return s')
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('Original constants:')
for i = 1, #proto.k do
    print('  [' .. i .. ']', type(proto.k[i]), tostring(proto.k[i]))
end

local n = str_encrypt.encrypt(proto, {key = 0x55})
print('Encrypted', n, 'string references')

print('Encrypted constants:')
for i = 1, #proto.k do
    print('  [' .. i .. ']', type(proto.k[i]), tostring(proto.k[i]))
end

local enc_bc = luac.dump(proto)
print('Encrypted size:', #bc, '->', #enc_bc)

local ok, f = pcall(load, enc_bc)
if ok then
    local ok2, result = pcall(f)
    print('Result:', tostring(result))
else
    print('Load failed:', f)
end

-- 测试2: 多个字符串和字符串拼接
print()
print('=== Test 2: multiple strings ===')
local func2 = load([[
local s1 = "hello"
local s2 = "world"
local s3 = "test"
return s1 .. " " .. s2 .. " " .. s3
]])
local bc2 = string.dec(string.dump(func2))
local proto2 = luac.undump(bc2, false)

str_encrypt.encrypt(proto2, {key = 0xAA})
local enc_bc2 = luac.dump(proto2)

local ok3, f2 = pcall(load, enc_bc2)
if ok3 then
    local ok4, result = pcall(f2)
    print('Result:', tostring(result), '(expected: hello world test)')
else
    print('Load failed:', f2)
end

-- 测试3: 有子函数
print()
print('=== Test 3: nested functions ===')
local func3 = load([[
local function greet(name)
    return "hello, " .. name
end
return greet("world")
]])
local bc3 = string.dec(string.dump(func3))
local proto3 = luac.undump(bc3, false)

str_encrypt.encrypt(proto3, {key = 0x33})
local enc_bc3 = luac.dump(proto3)

local ok5, f3 = pcall(load, enc_bc3)
if ok5 then
    local ok6, result = pcall(f3)
    print('Result:', tostring(result), '(expected: hello, world)')
else
    print('Load failed:', f3)
end
