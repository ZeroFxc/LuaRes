local const_poison = require('const_poison')
local luac = require('luac')

-- 测试1: 简单函数
local func = load('local a = 1; local b = "hello"; local c = true; return a .. b .. tostring(c)')
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('Test 1: simple function')
print('Original sizek:', #proto.k)
local n = const_poison.poison(proto, {count=10})
print('Poisoned:', n, 'constants')
print('New sizek:', #proto.k)

local poisoned_bc = luac.dump(proto)
print('Size:', #bc, '->', #poisoned_bc)

local ok, f = pcall(load, poisoned_bc)
if ok then
    local ok2, result = pcall(f)
    print('Result:', tostring(result))
else
    print('Load failed:', f)
end

-- 测试2: 有子函数的复杂脚本
print()
print('Test 2: nested functions')
local func2 = load([[
local function add(a, b) return a + b end
local function mul(a, b) return a * b end
local x = add(3, 4)
local y = mul(x, 2)
return x + y
]])
local bc2 = string.dec(string.dump(func2))
local proto2 = luac.undump(bc2, false)

print('Original main sizek:', #proto2.k)
print('Original sub-protos:', #proto2.p)
for i = 1, #proto2.p do
    print('  sub', i, 'sizek:', #proto2.p[i].k)
end

local n2 = const_poison.poison(proto2, {count=5})
print('Poisoned total:', n2)

local poisoned_bc2 = luac.dump(proto2)
local ok3, f2 = pcall(load, poisoned_bc2)
if ok3 then
    local ok4, result = pcall(f2)
    print('Result:', tostring(result), '(expected 21)')
else
    print('Load failed:', f2)
end

-- 测试3: 大量投毒
print()
print('Test 3: heavy poisoning (100 constants)')
local func3 = load('return 42')
local bc3 = string.dec(string.dump(func3))
local proto3 = luac.undump(bc3, false)
print('Original sizek:', #proto3.k)
const_poison.poison(proto3, {count=100, min_tag=0x80, max_tag=0xFF})
print('New sizek:', #proto3.k)
local poisoned_bc3 = luac.dump(proto3)
print('Size:', #bc3, '->', #poisoned_bc3)
local ok5, f3 = pcall(load, poisoned_bc3)
if ok5 then
    local ok6, result = pcall(f3)
    print('Result:', tostring(result), '(expected 42)')
else
    print('Load failed:', f3)
end

print()
print('All tests done!')
