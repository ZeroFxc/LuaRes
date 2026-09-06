package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/reverse/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local str_encrypt = require('str_encrypt')
local destr_encrypt = require('destr_encrypt')

local src = "local s='hello world'; print(s); local t={key='value'}; print(t.key); print(t['key'])"
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

str_encrypt.encrypt(proto, {key=0x55})
print("encrypt done, p count=" .. #proto.p)

destr_encrypt.clean(proto)
print("clean done, p count=" .. #proto.p)

print("dumping...")
local out = luac.dump(proto)
print("dump done, size=" .. #out)

print("loading...")
local f2 = load(out)
print("load done")

f2()
print("DONE")
