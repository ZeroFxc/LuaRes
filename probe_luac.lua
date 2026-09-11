local luac = require("luac")
local names = {}
for k,v in pairs(luac) do names[#names+1] = k end
table.sort(names)
print("luac fields:")
for _,n in ipairs(names) do print("  "..n.." = "..type(luac[n])) end
