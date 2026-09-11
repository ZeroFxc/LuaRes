local function f(x)
  local a = x + 1
  a = a * 2
  a = a - 3
  a = a // 2
  a = a & 7
  return a
end
print(f(10))
print(f(20))
