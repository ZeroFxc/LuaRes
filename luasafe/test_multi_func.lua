-- 多子函数测试脚本
-- 用于测试在子函数中注入 OP_48 和垃圾 upvalue

local function add(a, b)
    return a + b
end

local function mul(a, b)
    local result = 0
    for i = 1, b do
        result = add(result, a)
    end
    return result
end

local function fib(n)
    if n <= 1 then
        return n
    end
    return add(fib(n - 1), fib(n - 2))
end

local function main()
    print("add(3,4)=" .. add(3, 4))
    print("mul(5,6)=" .. mul(5, 6))
    for i = 1, 10 do
        print("fib(" .. i .. ")=" .. fib(i))
    end
    print("all done")
end

main()
