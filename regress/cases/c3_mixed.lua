local t = {10,20,30}
local sum = 0
for k,v in pairs(t) do sum = sum + v end
local i = 0
while i < 3 do i = i + 1; sum = sum + i end
for n=3,1,-1 do print("down", n) end
for n=1,4 do
  if n == 2 then sum = sum + 100 elseif n == 4 then break end
end
print("sum", sum)
