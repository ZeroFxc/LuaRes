package.path = package.path .. ";E:/LuaRes/luatools/?.lua"
local luac = require('luac')
local str_encrypt = require('str_encrypt')

local src = "local t={}; t[1]='value'; print(t[1])"
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

str_encrypt.encrypt(proto, {key=0x55})

local out = luac.dump(proto)
local f2 = load(out)
print("=== run ===")
f2()
