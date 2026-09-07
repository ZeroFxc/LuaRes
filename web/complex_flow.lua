-- 复杂控制流测试
local function fib(n)
  if n <= 1 then return n end
  return fib(n-1) + fib(n-2)
end

local function quicksort(arr, low, high)
  if low >= high then return end
  local pivot = arr[high]
  local i = low - 1
  for j = low, high - 1 do
    if arr[j] <= pivot then
      i = i + 1
      arr[i], arr[j] = arr[j], arr[i]
    end
  end
  arr[i+1], arr[high] = arr[high], arr[i+1]
  local p = i + 1
  quicksort(arr, low, p - 1)
  quicksort(arr, p + 1, high)
end

local sum = 0
for i = 1, 20 do
  if i % 3 == 0 then
    sum = sum + i
  elseif i % 5 == 0 then
    sum = sum - i
  else
    sum = sum + 1
  end
end

local n = 10
while n > 0 do
  n = n - 1
  if n == 5 then break end
end

local count = 0
repeat
  count = count + 1
until count >= 7

local arr = {9, 3, 7, 1, 8, 2, 6, 4, 5}
quicksort(arr, 1, #arr)

local total = 0
for _, v in ipairs(arr) do
  total = total + v
end

local closure_test = (function()
  local x = 0
  return function()
    x = x + 1
    return x
  end
end)()
local c1 = closure_test()
local c2 = closure_test()

local nested = 0
for a = 1, 3 do
  for b = 1, 3 do
    if a + b == 4 then
      nested = nested + a * b
    end
  end
end

print("sum=", sum)
print("n=", n)
print("count=", count)
print("fib10=", fib(10))
print("sorted=", table.concat(arr, ","))
print("total=", total)
print("closure=", c1 + c2)
print("nested=", nested)
