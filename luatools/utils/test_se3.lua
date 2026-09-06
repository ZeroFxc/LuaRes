package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local se = require('str_encrypt')

local src = io.open('utils/ad_test.lua', 'rb'):read('*a')
local bc = string.dec(string.dump(load(src)))
local p = luac.undump(bc, false)
local n = se.encrypt(p)
print('encrypted', n, 'strings')
print('sizecode:', #p.code, 'sizek:', #p.k)
local enc = luac.dump(p)
print('dumped size:', #enc)
local f, err = load(enc)
if not f then print('LOAD FAILED:', tostring(err):sub(1,200)); os.exit(1) end
local old_print = print
print = function() end
local ok, r = pcall(f)
print = old_print
if not ok then print('RUN FAILED:', tostring(r):sub(1,200)); os.exit(1) end
print('OK')
