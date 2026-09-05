local f = function() return 42 end
local bc = string.dump(f)
print("length:", #bc)
io.write("header: ")
for i = 1, math.min(32, #bc) do
    io.write(string.format("%02X ", string.byte(bc, i)))
end
print()
-- try undump with encrypted=true
local ok, proto = pcall(luac.undump, bc, true)
print("undump encrypted=true:", ok, proto and "ok" or tostring(proto))
local ok2, proto2 = pcall(luac.undump, bc, false)
print("undump encrypted=false:", ok2, proto2 and "ok" or tostring(proto2))
