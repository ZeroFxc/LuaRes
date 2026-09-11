local function counter(start)
  local function step(d) start = start + d; return start end
  return step
end
local s = counter(100)
local t = 0
while t < 3 do s(t); t = t + 1 end
print("d", s(0))
