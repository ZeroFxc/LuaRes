-- luacapi log 测试脚本
local t = {}
t.x = 42
t.name = "hello world"
for i = 1, 3 do
    t[i] = i * 10
end
local function add(a, b)
    return a + b
end
print("sum =", add(t.x, 8))
print(t.name)
