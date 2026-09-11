-- 简单 RETURN B>1 测试
local function retB3()
    local a = 10
    local b = 20
    local c = 30
    local d = 40
    return a, b
end

local r5, r6 = retB3()
print("r5=", r5, "r6=", r6)
if r5 ~= 10 or r6 ~= 20 then
    print("RETURN B>1 test error")
else
    print("RETURN B>1 test passed")
end

-- 多返回值测试
local function retMulti()
    local x = 100
    local y = 200
    local z = 300
    return x, y, z
end

local m1, m2, m3 = retMulti()
print("m1=", m1, "m2=", m2, "m3=", m3)
if m1 ~= 100 or m2 ~= 200 or m3 ~= 300 then
    print("multi return test error")
else
    print("multi return test passed")
end
