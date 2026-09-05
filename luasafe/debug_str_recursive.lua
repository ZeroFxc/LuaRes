local str_encrypt = require('str_encrypt')
local luac = require('luac')

-- 简单递归函数测试
local src = [[
local function fact(n)
    if n <= 1 then return 1 end
    return n * fact(n - 1)
end
return fact(5)
]]

local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('=== Original ===')
print('main sizek:', #proto.k, 'sizep:', #proto.p)
print('main code:')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    print(string.format('  [%2d] op=%d A=%d', i, op, a))
end
if proto.p and #proto.p > 0 then
    print('sub1 code:')
    for i = 1, #proto.p[1].code do
        local op = luac.GET_OPCODE(proto.p[1].code[i])
        local a = luac.GETARG_A(proto.p[1].code[i])
        print(string.format('  [%2d] op=%d A=%d', i, op, a))
    end
end

print()
print('=== Encrypting... ===')
str_encrypt.encrypt(proto, {key=0x55})

print()
print('=== Encrypted ===')
print('main sizek:', #proto.k, 'sizep:', #proto.p)
print('main code (first 20):')
for i = 1, math.min(20, #proto.code) do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    print(string.format('  [%2d] op=%d A=%d', i, op, a))
end

local enc_bc = luac.dump(proto)
local ok, f = pcall(load, enc_bc)
if ok then
    local ok2, result = pcall(f)
    print('Result:', tostring(result), '(expected 120)')
else
    print('Load failed:', f)
end
