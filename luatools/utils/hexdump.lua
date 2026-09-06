local f = io.open("E:/LuaRes/fangtd.lua", "rb")
local data = f:read(64)
f:close()
for i = 1, 64 do
    io.write(string.format("%02X ", data:byte(i)))
    if i % 16 == 0 then io.write("\n") end
end
io.write("\n")
-- 解析 header
print("signature: " .. string.format("%02X %02X %02X %02X", data:byte(1,4)))
print("version: 0x" .. string.format("%02X", data:byte(5)))
print("format: 0x" .. string.format("%02X", data:byte(6)))
print("endianness: 0x" .. string.format("%02X", data:byte(7)))
print("sizeof(int): " .. data:byte(8))
print("sizeof(size_t): " .. data:byte(9))
print("sizeof(Instruction): " .. data:byte(10))
print("sizeof(lua_Integer): " .. data:byte(11))
print("sizeof(lua_Number): " .. data:byte(12))
io.write("LUAC_INT: ")
for i = 13, 20 do io.write(string.format("%02X ", data:byte(i))) end
io.write("\n")
io.write("LUAC_NUM: ")
for i = 21, 28 do io.write(string.format("%02X ", data:byte(i))) end
io.write("\n")
print("upvalue count: " .. data:byte(29))
