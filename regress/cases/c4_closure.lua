local function acc(...)
  local s = 0
  for _,v in ipairs({...}) do s = s + v end
  return s
end
local r = acc(1,2,3,4,5)
print("acc", r)
local function counter()
  local x = 0
  return function() x = x + 1; return x end
end
local c = counter()
print(c(), c(), c())
for i=1,3 do
  local function f(y) return y + i end
  print("f", f(10))
end
