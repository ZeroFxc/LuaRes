package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local src = io.open('utils/ad_test.lua', 'rb'):read('*a')
local bc = string.dec(string.dump(load(src)))
local mod = arg[1]
local p = luac.undump(bc, false)
if mod == 'str_split' then luac.str_split_c(p)
elseif mod == 'opaque_junk' then luac.opaque_junk_c(p, {count=10})
elseif mod == 'luac_obfuscate' then luac.luac_obfuscate_c(p)
elseif mod == 'luac_flatten' then luac.luac_flatten_c(p)
elseif mod == 'opaque_predicate' then luac.opaque_predicate_c(p)
end
print(mod .. ': code=' .. #p.code)
local enc = luac.dump(p)
print(mod .. ': dumped ' .. #enc .. ' bytes')
local f = load(enc)
print(mod .. ': load=' .. tostring(f ~= nil))
