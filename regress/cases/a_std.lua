print(6)
print("6")
print({6})
print({"6"})
print(true)
print(false)
print(nil)
print(6.6)
print((function (x) return {x} end)(6))
print((function (x) return x end)(6))
print((function() return 6 end)())
print((function (...) return ... end)(6))
print((function (...) return {...} end)(6))
print(#"6")
print(tostring(6).."")
local ver = _VERSION
if ver == "Lua 5.2" then print("v52")
elseif ver == "Lua 5.3" then print("v53")
else print("vxx", ver) end

local function loopit(n)
  local s = 0
  local k = 1
  while k <= n do s = s + k; k = k + 1 end
  return s
end
print("while", loopit(5))

local acc = {}
for i=1,5 do
  acc[i] = "item" .. i
end
for i=1,#acc do print("arr", acc[i]) end

local rep = 0
repeat
  rep = rep + 1
until rep >= 4
print("rep", rep)
