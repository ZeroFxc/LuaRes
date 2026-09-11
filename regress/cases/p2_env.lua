local names = {"alpha", "beta", "gamma", "delta"}
local result = {}
local i = 1
while i <= #names do
  local key = "key_" .. names[i]
  result[i] = key .. "=" .. (i * 10)
  i = i + 1
end
for idx, v in ipairs(result) do
  print(idx, v)
end
local rep = 0
repeat
  rep = rep + 1
  local tmp = {rep, rep + 1, "val"}
  print(tmp[1], tmp[2], tmp[3])
until rep >= 3
print("done", #names, result[2])
