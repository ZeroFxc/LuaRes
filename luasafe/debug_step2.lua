local str_encrypt = require('str_encrypt')
local luac = require('luac')

local function test(name, src, expected)
    io.write(string.format('%-35s ', name))
    io.flush()
    local func = load(src)
    local bc = string.dec(string.dump(func))
    local proto = luac.undump(bc, false)
    str_encrypt.encrypt(proto, {key=0x55})
    local enc_bc = luac.dump(proto)
    local ok, f = pcall(load, enc_bc)
    if not ok then print('LOAD FAIL: ' .. tostring(f)); return end
    local ok2, result = pcall(f)
    if not ok2 then print('RUN FAIL: ' .. tostring(result)); return end
    if tostring(result) == expected then print('PASS')
    else print('WRONG: ' .. tostring(result) .. ' (expected ' .. expected .. ')') end
end

-- 5a: factorial + greet + for
test('fact+greet+for', [[
local function factorial(n)
    if n <= 1 then return 1 end
    return n * factorial(n - 1)
end
local function greet(name)
    return "hello, " .. name .. "!"
end
local total = 0
for i = 1, 10 do total = total + i end
return greet("world") .. factorial(5)
]], 'hello, world!120')

-- 5b: 3函数无递归 + for + 多字符串
test('3func-norec+for+multi', [[
local function add(a, b) return a + b end
local function mul(a, b) return a * b end
local function greet(name)
    return "hello, " .. name .. "!"
end
local total = 0
for i = 1, 10 do total = add(total, i) end
return greet("world") .. " t=" .. total .. " m=" .. mul(3,4)
]], 'hello, world! t=55 m=12')

-- 5c: factorial + greet + 多字符串（无 for）
test('fact+greet+multistr', [[
local function factorial(n)
    if n <= 1 then return 1 end
    return n * factorial(n - 1)
end
local function greet(name)
    return "hello, " .. name .. "!"
end
local msg = greet("world")
local fact = factorial(5)
return msg .. " total=" .. 30 .. " fact=" .. fact
]], 'hello, world! total=30 fact=120')

-- 5d: 完整但去掉 factorial 递归
test('full-no-recursion', [[
local function double(n) return n * 2 end
local function is_even(n) return n % 2 == 0 end
local function greet(name)
    return "hello, " .. name .. "!"
end
local total = 0
for i = 1, 10 do
    if is_even(i) then total = total + i end
end
local msg = greet("world")
local d = double(5)
return msg .. " total=" .. total .. " d=" .. d
]], 'hello, world! total=30 d=10')
