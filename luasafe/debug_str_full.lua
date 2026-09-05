local str_encrypt = require('str_encrypt')
local luac = require('luac')

-- 完整组合测试脚本（和 test_combination.lua 一样）
local src = [[
local function factorial(n)
    if n <= 1 then
        return 1
    end
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
    if is_even(i) then
        total = total + i
    end
end

local msg = greet("world")
local fact = factorial(5)
return msg .. " total=" .. total .. " fact=" .. fact
]]

local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('=== Original ===')
print('main sizek:', #proto.k, 'sizep:', #proto.p)

print()
print('=== Encrypting... ===')
str_encrypt.encrypt(proto, {key=0x55})

print()
print('=== Encrypted ===')
print('main sizek:', #proto.k, 'sizep:', #proto.p)

local enc_bc = luac.dump(proto)
local ok, f = pcall(load, enc_bc)
if ok then
    local ok2, result = pcall(f)
    print('Result:', tostring(result))
    print('Expected: hello, world! total=30 fact=120')
else
    print('Load failed:', f)
end
