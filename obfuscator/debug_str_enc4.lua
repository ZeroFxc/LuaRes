package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/reverse/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local str_encrypt = require('str_encrypt')

local src = "local t={key='value'}; print(type(t)); for k,v in pairs(t) do print(k,v) end; print('t.key='..tostring(t.key))"
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

str_encrypt.encrypt(proto, {key=0x55})

local out = luac.dump(proto)
local f2 = load(out)
print("=== run ===")
f2()
