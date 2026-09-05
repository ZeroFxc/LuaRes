local f = io.open("E:/LuaRes/fangtd_fixed.lua", "rb")
local data = f:read(40)
f:close()

print("=== Fixed header (first 40 bytes) ===")
for i = 1, 40 do
    io.write(string.format("%02X ", data:byte(i)))
    if i % 16 == 0 then io.write("\n") end
end
io.write("\n\n")

print("signature: " .. string.format("%02X %02X %02X %02X", data:byte(1,4)))
print("version: 0x" .. string.format("%02X", data:byte(5)))
print("format: 0x" .. string.format("%02X", data:byte(6)))
print("LUAC_DATA: " .. string.format("%02X %02X %02X %02X %02X %02X", data:byte(7,12)))
print("sizes: " .. string.format("%d %d %d %d %d", data:byte(13,17)))
io.write("LUAC_INT: ")
for i = 18, 25 do io.write(string.format("%02X ", data:byte(i))) end
io.write("\n")
io.write("LUAC_NUM: ")
for i = 26, 33 do io.write(string.format("%02X ", data:byte(i))) end
io.write("\n")
print("upvalue count: " .. data:byte(34))

-- 验证 LUAC_NUM 是否 = 3.14159
local bytes = ""
for i = 26, 33 do bytes = bytes .. string.char(data:byte(i)) end
-- 用 Lua 解析 double（小端）
local sign = 1
local exp = 0
local mantissa = 0
local b = {}
for i = 1, 8 do b[i] = data:byte(25 + i) end
-- 小端: b[1] 是最低字节
local raw = 0
for i = 8, 1, -1 do raw = raw * 256 + b[i] end
sign = (raw >= 0x8000000000000000) and -1 or 1
exp = math.floor(raw / 0x10000000000000) % 0x800
mantissa = raw % 0x10000000000000
local value
if exp == 0 and mantissa == 0 then
    value = 0
elseif exp == 0x7FF then
    value = mantissa == 0 and math.huge or (0/0)
else
    value = sign * (1 + mantissa / 0x10000000000000) * 2^(exp - 1023)
end
print("LUAC_NUM value: " .. tostring(value))
