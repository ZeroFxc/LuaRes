local s = 0
for i=1,5 do
  if i % 2 == 0 then s = s + i else s = s - i end
end
print("s=", s)
for j=1,3 do print("j", j) end
print("done")
