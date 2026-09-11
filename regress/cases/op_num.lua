local function f(a)
  local r = 0
  for z = 1, a do r = r + z end
  return r
end
print(f(3))
