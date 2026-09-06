-- protect_robustness.lua - test full protect pipeline on complex scenarios
local luac = require("luac")
local protect = require("protect")

local passed = 0
local failed = 0

local function test(name, func, ...)
    local args = {...}
    local ok_orig, r1_orig, r2_orig = pcall(func, table.unpack(args))
    local bc = string.dec(string.dump(func))
    local ok_prot, out = pcall(protect, bc)
    if not ok_prot then
        failed = failed + 1
        print(string.format("  [FAIL] %s (protect error: %s)", name, tostring(out)))
        return
    end
    local prot_func = load(out)
    local ok_prot2, r1_prot, r2_prot
    if prot_func then
        ok_prot2, r1_prot, r2_prot = pcall(prot_func, table.unpack(args))
    else
        ok_prot2 = false; r1_prot = "load failed"
    end
    local match = (ok_orig == ok_prot2) and (r1_orig == r1_prot) and (r2_orig == r2_prot)
    if match then
        passed = passed + 1
        print(string.format("  [PASS] %s", name))
    else
        failed = failed + 1
        print(string.format("  [FAIL] %s orig=(%s,%s,%s) prot=(%s,%s,%s)", name,
            tostring(ok_orig), tostring(r1_orig), tostring(r2_orig),
            tostring(ok_prot2), tostring(r1_prot), tostring(r2_prot)))
    end
end

print("=== Robustness Tests for Full Protect Pipeline ===")

-- 1. Recursion
test("recursive factorial", function(n)
    if n <= 1 then return 1 end
    return n * debug.getinfo(1).func(n - 1)
end, 10)

-- Use a global for recursion
_G._rec_fib = function(n)
    if n <= 1 then return n end
    return _G._rec_fib(n-1) + _G._rec_fib(n-2)
end
test("recursive fibonacci", _G._rec_fib, 15)

-- 2. Closures / upvalues
test("closure counter", function()
    local count = 0
    local inc = function()
        count = count + 1
        return count
    end
    return inc(), inc(), inc()
end)

test("closure with multiple upvalues", function(a, b)
    local x = a
    local y = b
    local step = function()
        x = x + 1
        y = y * 2
        return x + y
    end
    return step(), step()
end, 10, 20)

-- 3. Nested functions
test("nested functions", function(a)
    local function inner1(x)
        local function inner2(y)
            return y * 2
        end
        return inner2(x) + 1
    end
    return inner1(a) + inner1(a+1)
end, 5)

-- 4. Multiple return values
test("multiple returns", function(a, b, c)
    return a + b, b * c, tostring(a) .. "_" .. tostring(b)
end, 3, 4, 5)

-- 5. Vararg
test("vararg sum", function(...)
    local sum = 0
    for i = 1, select('#', ...) do
        sum = sum + select(i, ...)
    end
    return sum
end, 1, 2, 3, 4, 5)

-- 6. Table operations
test("table iteration", function(t)
    local sum = 0
    for k, v in pairs(t) do
        sum = sum + v
    end
    return sum
end, {a=1, b=2, c=3, d=4, e=5})

test("table concat", function(n)
    local t = {}
    for i = 1, n do
        t[i] = "item_" .. i
    end
    return table.concat(t, ",")
end, 5)

-- 7. String operations
test("string gmatch", function(s)
    local count = 0
    for word in s:gmatch("%w+") do
        count = count + 1
    end
    return count
end, "hello world foo bar")

test("string format", function(a, b)
    return string.format("%d + %d = %d", a, b, a+b)
end, 7, 8)

-- 8. Math operations
test("math pow", function(a, b)
    return a ^ b
end, 2, 10)

test("bitwise ops", function(a, b)
    return (a & b) | (a ~ b), a << 2, b >> 1
end, 0xFF, 0x0F)

-- 9. Deep nesting (10 levels)
test("deep if nesting", function(n)
    local x = 0
    if n > 0 then
        if n > 1 then
            if n > 2 then
                if n > 3 then
                    if n > 4 then
                        if n > 5 then
                            if n > 6 then
                                if n > 7 then
                                    if n > 8 then
                                        if n > 9 then
                                            x = 100
                                        else x = 9 end
                                    else x = 8 end
                                else x = 7 end
                            else x = 6 end
                        else x = 5 end
                    else x = 4 end
                else x = 3 end
            else x = 2 end
        else x = 1 end
    else x = 0 end
    return x
end, 7)

-- 10. Many elseif branches
test("many elseif", function(n)
    if n == 1 then return "one"
    elseif n == 2 then return "two"
    elseif n == 3 then return "three"
    elseif n == 4 then return "four"
    elseif n == 5 then return "five"
    elseif n == 6 then return "six"
    elseif n == 7 then return "seven"
    elseif n == 8 then return "eight"
    elseif n == 9 then return "nine"
    elseif n == 10 then return "ten"
    else return "other" end
end, 7)

-- 11. Function with no params / no returns
test("no params no returns", function()
    local x = 1 + 2
    return x
end)

-- 12. Boolean logic
test("boolean logic", function(a, b)
    if a and b then return "both"
    elseif a or b then return "one"
    else return "none" end
end, true, false)

-- 13. Numeric for loop (flatten skips loops, but protect should handle)
test("numeric for", function(n)
    local sum = 0
    for i = 1, n do
        sum = sum + i
    end
    return sum
end, 100)

-- 14. While loop
test("while loop", function(n)
    local sum = 0
    local i = 1
    while i <= n do
        sum = sum + i
        i = i + 1
    end
    return sum
end, 50)

-- 15. Repeat until
test("repeat until", function(n)
    local sum = 0
    local i = 1
    repeat
        sum = sum + i
        i = i + 1
    until i > n
    return sum
end, 30)

print(string.format("\n=== Results: %d passed, %d failed ===", passed, failed))
