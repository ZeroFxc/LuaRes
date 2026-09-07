-- vararg with nil values
local function f(...)
  local args = {...}
  local n = select('#', ...)
  local parts = {}
  for i = 1, n do parts[i] = tostring(args[i]) end
  return table.concat(parts, ","), n
end

local s, n = f(1, nil, 3, nil, 5)
print("vararg nil:", s, "n=" .. n)

-- function returning nil in the middle
local function multi()
  return 1, nil, 3
end
local a, b, c = multi()
print("multi ret:", tostring(a), tostring(b), tostring(c))

-- pcall with nil args
local function g(x, y, z)
  return x, y, z
end
local ok, r1, r2, r3 = pcall(g, 1, nil, 3)
print("pcall nil args:", ok, tostring(r1), tostring(r2), tostring(r3))

-- VARARG instruction directly
local function h(...)
  return ...
end
local x1, x2, x3 = h("a", nil, "c")
print("pass-through:", tostring(x1), tostring(x2), tostring(x3))

-- nil in table constructor from vararg
local function pack(...)
  return {...}
end
local t = pack(1, nil, 3)
print("table pack:", tostring(t[1]), tostring(t[2]), tostring(t[3]), "n=" .. tostring(select('#', unpack(t))))

print("ALL VARARG TESTS PASSED")
