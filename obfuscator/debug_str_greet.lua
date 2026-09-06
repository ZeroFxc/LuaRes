local str_encrypt = require('str_encrypt')
local luac = require('luac')

-- 测试：有字符串拼接的函数
local src = [[
local function greet(name)
    return "hello, " .. name .. "!"
end
return greet("world")
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
    print('sub1 (greet) sizek:', #proto.p[1].k)
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

local enc_bc = luac.dump(proto)
local ok, f = pcall(load, enc_bc)
if ok then
    local ok2, result = pcall(f)
    print('Result:', tostring(result), '(expected: hello, world!)')
else
    print('Load failed:', f)
end
