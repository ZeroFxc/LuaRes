local str_encrypt = require('str_encrypt')
local luac = require('luac')

local function test(name, src, expected)
    io.write(string.format('%-30s ', name))
    io.flush()
    local func = load(src)
    local bc = string.dec(string.dump(func))
    local proto = luac.undump(bc, false)
    str_encrypt.encrypt(proto, {key=0x55})
    local enc_bc = luac.dump(proto)
    local ok, f = pcall(load, enc_bc)
    if not ok then
        print('LOAD FAIL: ' .. tostring(f))
        return
    end
    local ok2, result = pcall(f)
    if not ok2 then
        print('RUN FAIL: ' .. tostring(result))
        return
    end
    if tostring(result) == expected then
        print('PASS')
    else
        print('WRONG: ' .. tostring(result) .. ' (expected ' .. expected .. ')')
    end
end

-- 测试1: 只有 greet + 调用
test('greet only', [[
local function greet(name)
    return "hello, " .. name .. "!"
end
return greet("world")
]], 'hello, world!')

-- 测试2: greet + 空 for 循环
test('greet + empty for', [[
local function greet(name)
    return "hello, " .. name .. "!"
end
for i = 1, 10 do end
return greet("world")
]], 'hello, world!')

-- 测试3: greet + for 循环（有循环体）
test('greet + for body', [[
local function greet(name)
    return "hello, " .. name .. "!"
end
local total = 0
for i = 1, 10 do
    total = total + i
end
return greet("world") .. total
]], 'hello, world!55')

-- 测试4: greet + is_even + for 循环
test('greet + is_even + for', [[
local function is_even(n)
    return n % 2 == 0
end
local function greet(name)
    return "hello, " .. name .. "!"
end
local total = 0
for i = 1, 10 do
    if is_even(i) then total = total + i end
end
return greet("world") .. total
]], 'hello, world!30')

-- 测试5: 完整（3函数 + for + 多字符串）
test('full', [[
local function factorial(n)
    if n <= 1 then return 1 end
    return n * factorial(n - 1)
end
local function is_even(n)
    return n % 2 == 0
end
local function greet(name)
    return "hello, " .. name .. "!"
end
local total = 0
for i = 1, 10 do
    if is_even(i) then total = total + i end
end
local msg = greet("world")
local fact = factorial(5)
return msg .. " total=" .. total .. " fact=" .. fact
]], 'hello, world! total=30 fact=120')
