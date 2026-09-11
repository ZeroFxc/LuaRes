package.path = package.path .. ';E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua'
local luac = require('luac')

-- 测试1: 纯解密函数(无自混淆)是否正确
local src = 'return function(s) local key=s:byte(1) local r="" for i=2,#s do r=r..string.char(string.byte(s,i)~key) end return r end'
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)
local dec = proto.p[1]
dec.upvalues[1].instack = 0
dec.upvalues[1].idx = 0
print('plain dec: maxstack=' .. dec.maxstacksize .. ' code=' .. #dec.code)

local key = 0x41
local enc = string.char(key)
for i = 1, #'world' do enc = enc .. string.char(string.byte('world', i) ~ key) end

local test_proto = luac.undump(string.dec(string.dump(load('return ...'))), false)
test_proto.p = {dec}
table.insert(test_proto.k, 1, enc)
test_proto.code = {
    luac.CREATE_ABx(1, 0, 0),
    luac.CREATE_ABx(44, 1, 0),
    luac.CREATE_ABC(0, 2, 0, 0),
    luac.CREATE_ABC(36, 1, 2, 2),
    luac.CREATE_ABC(0, 0, 1, 0),
    luac.CREATE_ABC(38, 0, 2, 0),
}
test_proto.maxstacksize = 3
local ok, r = pcall(function() return load(luac.dump(test_proto))() end)
print('plain decrypt result:', ok, tostring(r))

-- 测试2: 自混淆后的解密函数
local im = require('instruction_mutate')
local op = require('opaque_predicate')
im.process_function(dec, {})
op.process_function(dec, {})
print('obfuscated dec: maxstack=' .. dec.maxstacksize .. ' code=' .. #dec.code)

local test_proto2 = luac.undump(string.dec(string.dump(load('return ...'))), false)
test_proto2.p = {dec}
table.insert(test_proto2.k, 1, enc)
test_proto2.code = {
    luac.CREATE_ABx(1, 0, 0),
    luac.CREATE_ABx(44, 1, 0),
    luac.CREATE_ABC(0, 2, 0, 0),
    luac.CREATE_ABC(36, 1, 2, 2),
    luac.CREATE_ABC(0, 0, 1, 0),
    luac.CREATE_ABC(38, 0, 2, 0),
}
test_proto2.maxstacksize = math.max(3, dec.maxstacksize + 2)
local ok2, r2 = pcall(function() return load(luac.dump(test_proto2))() end)
print('obfuscated decrypt result:', ok2, tostring(r2))
