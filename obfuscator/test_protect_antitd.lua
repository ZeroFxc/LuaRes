local protect = require("protect")

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

-- 完整 pipeline（含 anti_td）
local out, stats = protect(bc, {})
print("Protected size: " .. #out)
print("Passes: " .. table.concat(stats.passes, " -> "))

-- 验证加载和执行
local ok, f = pcall(load, out)
print("Load: " .. tostring(ok))
if ok then
    local ok2, a, b, c = pcall(f)
    print("Exec: " .. tostring(ok2) .. " " .. tostring(a) .. " " .. tostring(b) .. " " .. tostring(c))
    print("Correct: " .. tostring(a == 30 and b == 200 and c == "sum=30, prod=200"))
else
    print("  Error: " .. tostring(f))
end

-- 测试不含 anti_td
print("\n--- Without anti_td ---")
local out2, stats2 = protect(bc, {no_anti_td = true})
print("Protected size: " .. #out2)
print("Passes: " .. table.concat(stats2.passes, " -> "))
local ok3, f2 = pcall(load, out2)
print("Load: " .. tostring(ok3))
if ok3 then
    local ok4, a, b, c = pcall(f2)
    print("Exec: " .. tostring(ok4) .. " " .. tostring(a) .. " " .. tostring(b) .. " " .. tostring(c))
end
