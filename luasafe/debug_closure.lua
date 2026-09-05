local str_encrypt = require('str_encrypt')
local luac = require('luac')

local src = [[
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
]]

local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('=== Original main CLOSURE instructions ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    if op == 44 then  -- CLOSURE
        local a = luac.GETARG_A(proto.code[i])
        local bx = luac.GETARG_Bx(proto.code[i])
        print(string.format('  [%d] CLOSURE A=%d Bx=%d (sub proto index)', i, a, bx))
    end
end

print()
print('=== Encrypting... ===')
str_encrypt.encrypt(proto, {key=0x55})

print()
print('=== Encrypted main CLOSURE instructions ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    if op == 44 then  -- CLOSURE
        local a = luac.GETARG_A(proto.code[i])
        local bx = luac.GETARG_Bx(proto.code[i])
        print(string.format('  [%d] CLOSURE A=%d Bx=%d (sub proto index)', i, a, bx))
    end
end

print()
print('main sizep:', #proto.p)
for i = 1, #proto.p do
    print(string.format('  p[%d]: sizek=%d code=%d', i, #proto.p[i].k, #proto.p[i].code))
end

-- 检查 greet 函数（应该是 p[3]）的 CLOSURE
print()
print('=== greet (p[3]) CLOSURE ===')
local greet = proto.p[3]
for i = 1, #greet.code do
    local op = luac.GET_OPCODE(greet.code[i])
    if op == 44 then
        local a = luac.GETARG_A(greet.code[i])
        local bx = luac.GETARG_Bx(greet.code[i])
        print(string.format('  [%d] CLOSURE A=%d Bx=%d', i, a, bx))
    end
end
print('greet sizep:', #greet.p)
