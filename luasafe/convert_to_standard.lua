-- convert_to_standard.lua: 将 andlua 格式字节码转换为标准 Lua 5.3 格式
-- andlua header (33 bytes): sig(4) + ver(1) + fmt(1) + LUAC_DATA(6) + sizes(5) + LUAC_INT(8) + LUAC_NUM(8)
-- standard header (28 bytes): sig(4) + ver(1) + fmt(1) + endianness(1) + sizes(5) + LUAC_INT(8) + LUAC_NUM(8)
-- 用法: lua_luac.exe convert_to_standard.lua <input.lua> <output.lua>

local input = arg[1]
local output = arg[2]

if not input or not output then
    print("Usage: lua_luac.exe convert_to_standard.lua <input.lua> <output.lua>")
    os.exit(1)
end

local f = io.open(input, "rb")
if not f then
    print("Error: cannot open " .. input)
    os.exit(1)
end
local data = f:read("*a")
f:close()

print("Input size: " .. #data .. " bytes")

-- 验证 andlua header
if data:byte(1) ~= 0x1B or data:byte(2) ~= 0x4C or data:byte(3) ~= 0x75 or data:byte(4) ~= 0x61 then
    print("Error: not a Lua bytecode (bad signature)")
    os.exit(1)
end
if data:byte(5) ~= 0x53 then
    print("Error: not Lua 5.3 (version=0x" .. string.format("%02X", data:byte(5)) .. ")")
    os.exit(1)
end

-- 检查是否是 andlua 格式（偏移 7-12 = LUAC_DATA 19 93 0D 0A 1A 0A）
local is_andlua = (data:byte(7) == 0x19 and data:byte(8) == 0x93 and
                   data:byte(9) == 0x0D and data:byte(10) == 0x0A and
                   data:byte(11) == 0x1A and data:byte(12) == 0x0A)

if not is_andlua then
    print("Warning: not andlua format (no LUAC_DATA), attempting direct conversion")
end

-- 标准 LUAC_NUM = 3.14159265358979323846 (little-endian)
local standard_luac_num = string.char(0x18, 0x2D, 0x44, 0x54, 0xFB, 0x21, 0x09, 0x40)

-- 转换 header
-- andlua: [1-6] sig+ver+fmt, [7-12] LUAC_DATA, [13-17] sizes, [18-25] LUAC_INT, [26-33] LUAC_NUM, [34] upvalue_count, [35+] function
-- standard: [1-6] sig+ver+fmt, [7] endianness, [8-12] sizes, [13-20] LUAC_INT, [21-28] LUAC_NUM, [29] upvalue_count, [30+] function

local header_out
if is_andlua then
    -- andlua 格式：移除 LUAC_DATA，添加 endianness，替换 LUAC_NUM
    header_out = data:sub(1, 6)           -- sig + ver + fmt
        .. string.char(0x01)                -- endianness (little-endian)
        .. data:sub(13, 25)                 -- sizes(5) + LUAC_INT(8) = 13 bytes
        .. standard_luac_num                -- standard LUAC_NUM(8)
        .. data:sub(34)                      -- upvalue_count + function
else
    -- 非 andlua 格式：假设已经是 28 字节标准 header，只替换 LUAC_NUM
    header_out = data:sub(1, 20) .. standard_luac_num .. data:sub(29)
end

print("Output size: " .. #header_out .. " bytes")

-- 验证可以被标准 Lua 加载
local ok, err = pcall(load, header_out)
print("Standard Lua load: " .. tostring(ok))
if not ok then
    print("  Error: " .. tostring(err))
end

-- 写入
local fout = io.open(output, "wb")
fout:write(header_out)
fout:close()
print("Written to " .. output)
