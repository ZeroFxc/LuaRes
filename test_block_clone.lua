-- 简单 tailcall 测试
local function multi(a, b, c)
    return a, b, c
end

local function tailB0(...)
    return multi(...)
end

local t1, t2, t3 = tailB0(100, 200, 300)
print("tailcall:", t1, t2, t3)
if t1 ~= 100 or t2 ~= 200 or t3 ~= 300 then
    print("TAILCALL TEST FAILED")
else
    print("TAILCALL TEST PASSED")
end

-- 简单 closure 测试
local function makeAdder(x)
    return function(y) return x + y end
end
local add5 = makeAdder(5)
local closureResult = add5(7)
print("closure:", closureResult)
if closureResult ~= 12 then
    print("CLOSURE TEST FAILED")
else
    print("CLOSURE TEST PASSED")
end

-- 简单 upvalue 测试
local function makeCounter()
    local count = 0
    return function()
        count = count + 1
        return count
    end
end
local c = makeCounter()
local u1 = c()
local u2 = c()
print("upvalue:", u1, u2)
if u1 ~= 1 or u2 ~= 2 then
    print("UPVALUE TEST FAILED")
else
    print("UPVALUE TEST PASSED")
end

print("done")
