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

print('=== Original MOVE instructions ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    if op == 0 then  -- MOVE
        local a = luac.GETARG_A(proto.code[i])
        local b = luac.GETARG_B(proto.code[i])
        print(string.format('  [%d] MOVE R%d = R%d', i, a, b))
    end
end

print()
print('=== Encrypting... ===')
str_encrypt.encrypt(proto, {key=0x55})

print()
print('=== Encrypted MOVE instructions ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    if op == 0 then  -- MOVE
        local a = luac.GETARG_A(proto.code[i])
        local b = luac.GETARG_B(proto.code[i])
        print(string.format('  [%d] MOVE R%d = R%d', i, a, b))
    end
end

print()
print('=== Encrypted instructions 15-25 ===')
for i = 15, 25 do
    if i > #proto.code then break end
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local b = luac.GETARG_B(proto.code[i])
    local c = luac.GETARG_C(proto.code[i])
    print(string.format('  [%2d] op=%d A=%d B=%d C=%d', i, op, a, b, c))
end
