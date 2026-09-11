-- 简单闭包 upvalue 测试
local function makeCounter()
    local count = 0
    return function()
        count = count + 1
        return count
    end
end

local c1 = makeCounter()
local c2 = makeCounter()
print(c1())  -- 1
print(c1())  -- 2
print(c2())  -- 1
print(c1())  -- 3
print(c2())  -- 2

-- 多 upvalue 测试
local function makeAdder(x)
    return function(y)
        return x + y
    end
end

local add5 = makeAdder(5)
local add10 = makeAdder(10)
print(add5(3))   -- 8
print(add10(3))  -- 13

-- 共享 upvalue 测试
local function makeShared()
    local shared = 0
    local function inc() shared = shared + 1 end
    local function get() return shared end
    return inc, get
end

local inc, get = makeShared()
inc()
inc()
inc()
print(get())  -- 3

print("简单闭包测试通过")
