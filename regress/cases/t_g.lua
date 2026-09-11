local function f(n)
  local s = 0
  local i = 1
  while i <= n do s = s + i; i = i + 1 end
  return s
end
print(f(3), f(10))
