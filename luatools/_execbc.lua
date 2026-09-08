local f = io.open("_crash2.bin", "rb")
local bc = f:read("*a")
f:close()
io.write("loaded "..#bc.." bytes\n"); io.flush()
local func, err = load(bc)
io.write("load: "..tostring(func).." err="..tostring(err).."\n"); io.flush()
if func then func() end
io.write("exec ok\n"); io.flush()
