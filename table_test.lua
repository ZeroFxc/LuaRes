-- 表使用方式大全

-- 基础构造
local t1 = {1, 2, 3}
local t2 = {a = 1, b = 2, c = 3}
local t3 = {["key"] = "value", [1] = "one"}

-- 嵌套表
local t4 = {
    x = {1, 2, 3},
    y = {a = 10, b = 20},
    z = {{1}, {2}, {3}}
}

-- 空表
local t5 = {}

-- 表访问
local v1 = t1[1]
local v2 = t2.a
local v3 = t3["key"]
local v4 = t4.x[2]
local v5 = t4.y.b

-- 表修改
t1[1] = 100
t2.a = 200
t3["new"] = "value"
t4.z[1][1] = 999

-- 表长度
local len1 = #t1
local len2 = #t5

-- 遍历
local sum = 0
for i = 1, #t1 do
    sum = sum + t1[i]
end

-- pairs 遍历
local count = 0
for k, v in pairs(t2) do
    count = count + 1
end

-- 表作为函数参数和返回值
local function mk_table(x, y)
    return {x = x, y = y, sum = x + y}
end
local t6 = mk_table(10, 20)

-- 元表
local mt = {
    __add = function(a, b) return a.x + b.x end
}
setmetatable(t6, mt)

-- 表拼接（用 .. 不可能，用 table.concat）
local s = table.concat(t1, ",")

print(v1, v2, v3, v4, v5, len1, sum, count, t6.x, t6.sum, s)
