-- save obfuscated bytecode: arg1=src arg2=mods arg3=seed arg4=outbc
local luac = require("luac")
local function rf(p) local f=assert(io.open(p,"rb")); local d=f:read("*a"); f:close(); return d end
local src=rf(arg[1]); luac.srand(tonumber(arg[3]) or 1)
local proto=luac.undump(string.dec(string.dump(assert(load(src)),true)),false)
for m in arg[2]:gmatch("[^,]+") do local ok,e=pcall(luac[m],proto); if not ok then io.stderr:write(m..": "..tostring(e).."\n"); os.exit(1) end end
local bc=luac.dump(proto)
local o=assert(io.open(arg[4],"wb")); o:write(bc); o:close()
io.write("size="..#bc.."\n")
