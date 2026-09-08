local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
io.write("undump ok: sizecode="..p.sizecode.." sizek="..p.sizek.."\n"); io.flush()
local bc = luac.dump(p, true)
io.write("dump len="..#bc.."\n"); io.flush()
-- compare with standard dump
local std_bc = string.dump(load(code), true)
io.write("std dump len="..#std_bc.."\n"); io.flush()
-- show first 32 bytes of each
io.write("luac: "); for i=1,32 do io.write(string.format("%02x ", bc:byte(i))) end; io.write("\n"); io.flush()
io.write("std:  "); for i=1,32 do io.write(string.format("%02x ", std_bc:byte(i))) end; io.write("\n"); io.flush()
local f, err = load(bc)
io.write("load: f="..tostring(f).." err="..tostring(err).."\n"); io.flush()
if f then f() end
