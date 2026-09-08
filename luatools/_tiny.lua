local luac = require("luac")
-- tiny script with if (logical + JMP)
local code = [[
local x = 5
if x > 3 then print("big") else print("small") end
]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.luac_obfuscate_c(p)
print("done, code="..p.sizecode)
