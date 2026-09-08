local luac = require("luac")
local f = io.open("_crash.bin", "rb")
local bc = f:read("*a")
f:close()
local p = luac.undump(bc, false)
io.write("undump ok: sizecode="..p.sizecode.." sizek="..p.sizek.."\n"); io.flush()
for i = 80, 95 do
    local k = p.k[i]
    io.write(string.format("k[%d]=%s %s\n", i, type(k), tostring(k):sub(1,30))); io.flush()
end
