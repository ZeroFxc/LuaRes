-- 各种循环结构测试
local x = 0

-- 1. numeric for
for i = 1, 10 do
  x = x + i
end

-- 2. while
local j = 0
while j < 5 do
  j = j + 1
  x = x + j
end

-- 3. repeat until
local k = 0
repeat
  k = k + 1
  x = x + k
until k >= 3

-- 4. generic for
local t = {a=1, b=2, c=3}
for key, val in pairs(t) do
  x = x + val
end

-- 5. 嵌套循环
for a = 1, 2 do
  for b = 1, 2 do
    x = x + a * b
  end
end

-- 6. 带break的循环
for i = 1, 100 do
  if i > 3 then break end
  x = x + i
end

print(x)
