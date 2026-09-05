-- 布尔值各种使用方法测试

-- 1. 直接赋值
local a = true
local b = false

-- 2. 变量间赋值
local c = a
local d = b

-- 3. 比较运算产生布尔值
local e = 1 > 2
local f = 1 < 2
local g = 1 >= 2
local h = 1 <= 2
local i = 1 == 2
local j = 1 ~= 2

-- 4. 逻辑运算
local k = a and b
local l = a or b
local m = not a

-- 5. 复杂逻辑
local n = (a and b) or (not c)
local o = (1 > 2) and (3 < 4) or (5 == 5)

-- 6. if 条件
if a then
    print("a is true")
end

if not b then
    print("b is false")
end

if a and b then
    print("both true")
elseif a or b then
    print("one true")
else
    print("none true")
end

-- 7. while 条件
local count = 0
while count < 3 do
    count = count + 1
end

-- 8. repeat-until
local x = 0
repeat
    x = x + 1
until x >= 5

-- 9. 三目运算模拟
local result = a and "yes" or "no"

-- 10. 函数返回布尔值
local function is_positive(n)
    return n > 0
end

local function is_even(n)
    return n % 2 == 0
end

-- 11. 布尔值作为函数参数
local function check(flag)
    if flag then
        return "enabled"
    else
        return "disabled"
    end
end

check(true)
check(false)
check(a)

-- 12. 表中的布尔值
local config = {
    debug = true,
    verbose = false,
    enabled = a,
}

-- 13. 布尔值拼接
local msg = "status: " .. tostring(a)

-- 14. 多重比较链
local function in_range(n, min, max)
    return n >= min and n <= max
end

-- 15. 异或模拟
local function xor(a, b)
    return (a and not b) or (not a and b)
end

print("done", a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, result, count, x, config.debug, msg, is_positive(5), is_even(4), in_range(5, 1, 10), xor(true, false))
