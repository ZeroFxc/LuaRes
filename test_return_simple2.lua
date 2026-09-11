-- 测试 1: 2 个局部变量，返回 2 个
local function test1()
    local a = 10
    local b = 20
    return a, b
end
local r1, r2 = test1()
print("test1:", r1, r2)

-- 测试 2: 3 个局部变量，返回前 2 个
local function test2()
    local a = 10
    local b = 20
    local c = 30
    return a, b
end
local r3, r4 = test2()
print("test2:", r3, r4)

-- 测试 3: 4 个局部变量，返回前 2 个
local function test3()
    local a = 10
    local b = 20
    local c = 30
    local d = 40
    return a, b
end
local r5, r6 = test3()
print("test3:", r5, r6)

-- 测试 4: 4 个局部变量，返回前 3 个
local function test4()
    local a = 10
    local b = 20
    local c = 30
    local d = 40
    return a, b, c
end
local r7, r8, r9 = test4()
print("test4:", r7, r8, r9)

print("done")
