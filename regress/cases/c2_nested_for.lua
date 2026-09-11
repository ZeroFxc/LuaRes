local out = {}
for i=1,3 do
  for j=1,3 do
    out[#out+1] = i*j
  end
end
print(table.concat(out, ","))
