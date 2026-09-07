-- comprehensive test target for obfuscation module smoke tests
local function fact(n)
    if n <= 1 then return 1 end
    return n * fact(n - 1)
end

local function fib(n)
    if n <= 1 then return n end
    return fib(n - 1) + fib(n - 2)
end

local function vararg_sum(...)
    local args = {...}
    local s = 0
    for _, v in ipairs(args) do s = s + v end
    return s, #args
end

local function multi_return()
    return 10, 20, 30
end

local function table_tests()
    local arr = {1, 2, 3, 4, 5}
    local sum = 0
    for i, v in ipairs(arr) do sum = sum + v * i end

    local hash = {name = "test", value = 42, active = true}
    local hash_sum = #hash.name + hash.value

    local nested = {a = {b = {c = 99}}}
    local nested_val = nested.a.b.c

    local mt = {__add = function(a, b) return a.val + b.val end}
    local o1 = setmetatable({val = 10}, mt)
    local o2 = setmetatable({val = 20}, mt)
    local mt_result = o1 + o2

    return sum + hash_sum + nested_val + mt_result
end

local function string_tests()
    local s = "hello"
    local s2 = s .. " world"
    local len = #s2
    local upper = string.upper(s)
    local sub = string.sub(s2, 1, 5)
    local fmt = string.format("x=%d y=%s", 42, "ok")
    return len + #upper + #sub + #fmt
end

local function math_tests()
    local a = math.floor(3.7)
    local b = math.ceil(2.3)
    local c = math.sqrt(16)
    local d = math.abs(-5)
    local e = 2 ^ 10
    local f = 10 % 3
    return a + b + c + d + e + f
end

local function loop_tests()
    local sum = 0
    for i = 1, 10 do sum = sum + i end
    local j = 0
    while j < 5 do j = j + 1; sum = sum + j end
    repeat
        sum = sum + 1
        j = j - 1
    until j <= 0
    local t = {a = 1, b = 2, c = 3}
    for k, v in pairs(t) do sum = sum + v end
    return sum
end

local function coroutine_test()
    local co = coroutine.create(function()
        local sum = 0
        for i = 1, 5 do
            sum = sum + i
            coroutine.yield(sum)
        end
        return sum
    end)
    local results = {}
    while true do
        local ok, val = coroutine.resume(co)
        if not ok then break end
        if val then results[#results + 1] = val end
        if coroutine.status(co) == "dead" then break end
    end
    return results[#results] or 0
end

local function closure_test()
    local counter = 0
    local function inc() counter = counter + 1; return counter end
    local function dec() counter = counter - 1; return counter end
    inc(); inc(); inc(); dec()
    return counter
end

local function main()
    local results = {}
    results.fact = fact(5)
    results.fib = fib(7)
    local vs, vn = vararg_sum(1, 2, 3, 4, 5)
    results.vararg = vs + vn
    local r1, r2, r3 = multi_return()
    results.multi = r1 + r2 + r3
    results.table = table_tests()
    results.string = string_tests()
    results.math = math_tests()
    results.loop = loop_tests()
    results.co = coroutine_test()
    results.closure = closure_test()

    local total = 0
    for _, v in pairs(results) do total = total + v end

    print("fact=" .. results.fact)
    print("fib=" .. results.fib)
    print("table=" .. results.table)
    print("string=" .. results.string)
    print("math=" .. results.math)
    print("loop=" .. results.loop)
    print("co=" .. results.co)
    print("closure=" .. results.closure)
    print("TOTAL=" .. total)
    print("SMOKE_TEST_OK")
end

main()
