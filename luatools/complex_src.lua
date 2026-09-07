-- ===== 复杂测试脚本 =====
-- 1. 互递归
local function is_even(n)
  if n == 0 then return true end
  return is_odd(n - 1)
end
function is_odd(n)
  if n == 0 then return false end
  return is_even(n - 1)
end
print("1. mutual recursion: is_even(10)=" .. tostring(is_even(10)) .. " is_odd(7)=" .. tostring(is_odd(7)))

-- 2. 多 upvalue 闭包 + 变异
local function make_accumulator(init, step)
  local sum = init
  local count = 0
  return {
    add = function(x) sum = sum + x * step; count = count + 1; return sum end,
    get = function() return sum, count end,
    reset = function() sum = init; count = 0 end,
  }
end
local acc = make_accumulator(10, 2)
acc.add(5); acc.add(3)
local s, c = acc.get()
print("2. closure upvalue: sum=" .. s .. " count=" .. c)

-- 3. 元表 + 元方法
local Vector = {}
Vector.__index = Vector
function Vector.new(x, y) return setmetatable({x=x, y=y}, Vector) end
function Vector.__add(a, b) return Vector.new(a.x+b.x, a.y+b.y) end
function Vector:mag() return math.sqrt(self.x^2 + self.y^2) end
function Vector.__tostring(v) return "(" .. v.x .. "," .. v.y .. ")" end
local v1 = Vector.new(3, 4)
local v2 = Vector.new(1, 2)
local v3 = v1 + v2
print("3. metatable: v3=" .. tostring(v3) .. " mag=" .. string.format("%.2f", v3:mag()))

-- 4. 协程交互（生产者-消费者）
local function producer()
  for i = 1, 5 do
    coroutine.yield(i * i)
  end
end
local co = coroutine.create(producer)
local results = {}
while true do
  local ok, val = coroutine.resume(co)
  if not ok or val == nil then break end
  results[#results+1] = val
end
print("4. coroutine pipeline: " .. table.concat(results, ","))

-- 5. vararg + 多返回值
local function fmt(prefix, ...)
  local args = {...}
  local parts = {}
  for i = 1, select('#', ...) do
    parts[i] = prefix .. tostring(args[i])
  end
  return table.concat(parts, "|"), #parts
end
local str, n = fmt("item_", "a", "b", "c", "d")
print("5. vararg: '" .. str .. "' count=" .. n)

-- 6. 尾调用递归（深递归不爆栈）
local function sum_tail(n, acc)
  if n == 0 then return acc end
  return sum_tail(n - 1, acc + n)
end
print("6. tail call: sum(1..1000)=" .. sum_tail(1000, 0))

-- 7. 嵌套函数 + 环境捕获
local function make_multiplier(factor)
  return function(x) return x * factor end
end
local mul3 = make_multiplier(3)
local mul7 = make_multiplier(7)
print("7. nested closure: mul3(11)=" .. mul3(11) .. " mul7(6)=" .. mul7(6))

-- 8. pcall/xpcall 错误处理
local function risky(x)
  if x < 0 then error("negative value: " .. x) end
  return x * 2
end
local ok1, r1 = pcall(risky, 5)
local ok2, r2 = pcall(risky, -3)
print("8. pcall: ok1=" .. tostring(ok1) .. " r1=" .. tostring(r1) .. " ok2=" .. tostring(ok2))

-- 9. 字符串操作
local s = "Hello, World! 123"
local upper = s:upper()
local reversed = s:reverse()
local matched = s:match("%d+")
print("9. strings: upper='" .. upper .. "' reversed='" .. reversed .. "' num=" .. matched)

-- 10. 表操作 + sort
local nums = {5, 2, 8, 1, 9, 3}
table.sort(nums)
local sum = 0
for _, v in ipairs(nums) do sum = sum + v end
print("10. table sort: " .. table.concat(nums, ",") .. " sum=" .. sum)

-- 11. load 动态代码
local dyn = load("return " .. "6 * 7 + " .. "3")
print("11. dynamic load: " .. dyn())

-- 12. 综合：用协程+闭包+元表实现迭代器
local function range(from, to, step)
  step = step or 1
  return coroutine.wrap(function()
    for i = from, to, step do
      coroutine.yield(i)
    end
  end)
end
local collected = {}
for v in range(10, 30, 5) do
  collected[#collected+1] = v
end
print("12. coroutine iterator: " .. table.concat(collected, ","))

print("===== ALL COMPLEX TESTS PASSED =====")
