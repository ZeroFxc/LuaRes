local luac = require("luac")
print("string.dec:", type(string.dec))
local src = "for i=1,3 do print(i) end"
local f = assert(load(src))
local d = string.dump(f, true)
print("dump len:", #d, "byte0:", string.byte(d,1))
local function try(label, bc)
  local ok, p = pcall(luac.undump, bc, false)
  print(label, ok, type(p))
  return ok and p
end
local p1 = try("raw", d)
if string.dec then local p2 = try("dec", string.dec(d)) end
