local luac = require("luac")
local func = load("print('hello')")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

local function op48()
    local a = 127
    local b = math.random(256, 511)
    local c = math.random(0, 200)
    return (a << 6) | (b << 23) | (c << 14) | 48
end

for i = 1, 100 do
    table.insert(p.code, op48())
end
p.lineinfo = {}
local out = luac.dump(p)
print("size=" .. #out .. " code=" .. #p.code)
local ok, f = pcall(load, out)
print("load=" .. tostring(ok))
if ok then f() end
