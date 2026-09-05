-- 数字使用方式大全
local a = 42
local b = -100
local c = 3.14
local d = 0
local e = 1
local f = 1000000
local g = -999999

-- 算术
local h = a + b
local i = a - b
local j = a * b
local k = a / b
local l = a % b
local m = a ^ 2

-- 位运算
local n = a & b
local o = a | b
local p = a ~ b
local q = ~a
local r = a << 2
local s = a >> 2

-- 比较
local t = a > b
local u = a < b
local v = a >= b
local w = a <= b
local x = a == b
local y = a ~= b

-- 逻辑
local z = a and b
local aa = a or b
local ab = not a

-- 数字作为表索引
local tbl = {[1] = "one", [2] = "two", [42] = "answer"}
local ac = tbl[42]

-- 数字作为函数参数
local function add(x, y) return x + y end
local ad = add(10, 20)

-- 循环中的数字
local sum = 0
for i = 1, 10 do
    sum = sum + i
end

-- 数字拼接
local ae = "value: " .. a

print(a, b, c, h, n, t, ac, ad, sum, ae)
