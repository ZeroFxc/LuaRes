
local luac = require("luac")
local f = loadfile("E:/LuaRes/luatools/smoke_target.lua")
local bc = string.dec(string.dump(f, true))
local p = luac.undump(bc, false)
luac.luac_flatten_c(p);luac.flatten_enhance_c(p);luac.condition_split_c(p);luac.opaque_predicate_c(p);luac.opaque_junk_c(p);luac.junk_c(p);
local d = luac.dump(p)
local r = load(d)
if r then r() else print("LOAD_FAIL") end
