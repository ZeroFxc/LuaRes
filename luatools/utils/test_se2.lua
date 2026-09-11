package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local se = require('str_encrypt')
local src = 'print("hello") print("world") print(6) print(true)'
local bc = string.dec(string.dump(load(src)))
local p = luac.undump(bc, false)
local n = se.encrypt(p)
print('encrypted', n, 'strings')
local enc = luac.dump(p)
local f, err = load(enc)
if not f then print('LOAD FAILED:', err); os.exit(1) end
f()
print('OK')
