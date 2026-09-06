local luac = require("luac")

local test_func = function()
    local function add(a, b) return a + b end
    local function mul(a, b) return a * b end
    local t = {x = 10, y = 20}
    local sum = add(t.x, t.y)
    local prod = mul(t.x, t.y)
    return sum, prod, string.format("sum=%d, prod=%d", sum, prod)
end

-- 直接用 string.dump，不用 string.dec
local bc = string.dump(test_func)
print("Original size: " .. #bc)
print("First byte: 0x" .. string.format("%02X", bc:byte(1)))

local p = luac.undump(bc, false)
print("main sizek=" .. #p.k)
for i = 1, #p.k do
    local v = p.k[i]
    print(string.format("  k[%d] type=%s value=%s", i, type(v), tostring(v)))
end

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
