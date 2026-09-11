package.path = package.path .. ';E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua'
local luac = require('luac')

local src = 'return function(s) local key=s:byte(1) local r="" for i=2,#s do r=r..string.char(string.byte(s,i)~key) end return r end'
local proto = luac.undump(string.dec(string.dump(load(src))), false)
local dec = proto.p[1]
dec.upvalues[1].instack = 0
dec.upvalues[1].idx = 0
print('plain dec: maxstack=' .. dec.maxstacksize .. ' code=' .. #dec.code)

local function enc(s, key)
    local r = string.char(key)
    for i = 1, #s do r = r .. string.char(string.byte(s, i) ~ key) end
    return r
end

local test_proto = luac.undump(string.dec(string.dump(load('return ...'))), false)
test_proto.p = {dec}
table.insert(test_proto.k, 1, enc('hello', 106))
table.insert(test_proto.k, 2, enc('world', 119))
test_proto.code = {
    luac.CREATE_ABx(1, 0, 0),
    luac.CREATE_ABx(1, 1, 1),
    luac.CREATE_ABx(44, 2, 0),
    luac.CREATE_ABC(0, 3, 0, 0),
    luac.CREATE_ABC(36, 2, 2, 2),
    luac.CREATE_ABC(0, 4, 2, 0),
    luac.CREATE_ABx(44, 2, 0),
    luac.CREATE_ABC(0, 3, 1, 0),
    luac.CREATE_ABC(36, 2, 2, 2),
    luac.CREATE_ABC(0, 5, 2, 0),
    luac.CREATE_ABC(41, 4, 4, 5),
    luac.CREATE_ABC(38, 4, 2, 0),
}
test_proto.maxstacksize = 6
local ok, r = pcall(function() return load(luac.dump(test_proto))() end)
print('plain two-call result:', ok, tostring(r))
