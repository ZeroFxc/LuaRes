local out = {}
local function P(...)
  local t = {...}
  local s = ""
  for i = 1, select("#", ...) do
    if i > 1 then s = s .. "|" end
    s = s .. tostring(t[i])
  end
  out[#out + 1] = s
end
local x = 4
P("rep", x)
print(table.concat(out, "#"))
