local luac = require("luac")

local test_func = function()
    local function add(a, b) return a + b end
    local function mul(a, b) return a * b end
    local t = {x = 10, y = 20}
    local sum = add(t.x, t.y)
    local prod = mul(t.x, t.y)
    return sum, prod, string.format("sum=%d, prod=%d", sum, prod)
end

local bc = string.dec(string.dump(test_func))
print("Original size: " .. #bc)

-- 纯 round-trip，不应用任何保护
local p = luac.undump(bc, false)
print("main sizek=" .. #p.k)
for i = 1, #p.k do print("  k[" .. i .. "]=" .. tostring(p.k[i])) end
print("p[1] sizek=" .. #p.p[1].k)
for i = 1, #p.p[1].k do print("  p[1].k[" .. i .. "]=" .. tostring(p.p[1].k[i])) end

local out = luac.dump(p)
print("Round-trip size: " .. #out)

local ok, f = pcall(load, out)
print("Load: " .. tostring(ok))
if ok then
    local ok2, a, b, c = pcall(f)
    print("Exec: " .. tostring(ok2) .. " " .. tostring(a) .. " " .. tostring(b) .. " " .. tostring(c))
else
    print("  Error: " .. tostring(f))
end
