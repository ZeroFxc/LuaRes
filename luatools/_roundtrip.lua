local luac = require("luac")
-- simple test: just dump and load a plain proto
local p = luac.undump(string.dec(string.dump(load("print(6) print('hello')"), true)), false)
io.write("orig: sizek="..p.sizek.."\n"); io.flush()
for i=0,p.sizek-1 do
    io.write(string.format("  k[%d]=%s %s\n", i, type(p.k[i]), tostring(p.k[i]):sub(1,30))); io.flush()
end
local bc = luac.dump(p, true)
io.write("dumped "..#bc.." bytes\n"); io.flush()
local f = load(bc)
io.write("load ok, executing:\n"); io.flush()
f()
io.write("exec ok\n"); io.flush()
