-- probe: apply full chain, then regcheck the FINAL in-memory proto
local luac = require("luac")
local function rf(p) local f=assert(io.open(p,"rb")); local d=f:read("*a"); f:close(); return d end
local src = rf(arg[1])
luac.srand(13)
local f = assert(load(src))
local bc = string.dec(string.dump(f, true))
local proto = luac.undump(bc, false)
local mods = arg[2]
for m in mods:gmatch("[^,]+") do
  local ok,err = pcall(luac[m], proto)
  if not ok then io.stderr:write("MOD ERR "..m..": "..tostring(err).."\n"); break end
  local msg = luac.regcheck_c(proto)
  if type(msg)=="string" and #msg>0 then
    io.write("AFTER "..m.." -> "..msg.."\n")
  end
end
io.write("FINAL regcheck: ["..tostring(luac.regcheck_c(proto)).."]\n")
