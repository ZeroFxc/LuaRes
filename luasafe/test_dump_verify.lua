local luac = require("luac")
local f = io.open("E:/LuaRes/fangtd.lua", "rb")
local data = f:read("*a")
f:close()

local p = luac.undump(data, false)
local function count(pp)
    local c = #pp.code
    for i = 1, #pp.p do c = c + count(pp.p[i]) end
    return c
end
local orig_code = count(p)
print("original instructions: " .. orig_code)

local out = luac.dump(p)
print("dump size: " .. #out)

local p2 = luac.undump(out, false)
local new_code = count(p2)
print("re-undump instructions: " .. new_code)
print("match: " .. tostring(orig_code == new_code))

-- test load
local ok, func = pcall(load, out)
print("load: " .. tostring(ok))
if ok then print("type: " .. type(func)) end
