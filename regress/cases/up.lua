local function make()
  local count = 0
  local function inc() count = count + 1; return count end
  local function get() return count end
  local function reset() count = 0 end
  return inc, get, reset
end
local inc, get, reset = make()
inc(); inc(); inc()
print("a", get())
reset()
for i = 1, 5 do inc() end
print("b", get())

local function adder(x)
  return function(y)
    x = x + y
    return function(z) return x + z end
  end
end
local a1 = adder(10)
local a2 = a1(5)
print("c", a2(3), a2(7))

local function counter(start)
  local function step(d) start = start + d; return start end
  return step
end
local s = counter(100)
local t = 0
while t < 3 do s(t); t = t + 1 end
print("d", s(0))
