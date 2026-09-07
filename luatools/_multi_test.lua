local luac = require("luac")
local f = loadfile("_multi.lua")
local bc = string.dec(string.dump(f, true))
local p = luac.undump(bc, false)

local n = luac.const_hide_c(p)
print("const_hide: " .. tostring(n))
local n2 = luac.str_encrypt_c(p)
print("str_encrypt: " .. tostring(n2))
local d = luac.dump(p)
print("dump ok: " .. tostring(#d))
local r = load(d)
if r then r() else print("LOAD_FAIL") end
