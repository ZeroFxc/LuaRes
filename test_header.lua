-- 测试字节码头部
local test_code = [[
print(6)
]]
local func = load(test_code)
local bc = string.dump(func, true)
io.write("header bytes: ")
for i = 1, math.min(16, #bc) do
    io.write(string.format("%02X ", bc:byte(i)))
end
io.write("\n")
print("length:", #bc)
