local str_encrypt = require('str_encrypt')
local luac = require('luac')

local src = [[
local function greet(name)
    return "hello, " .. name
end
return greet("world")
]]

local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)
str_encrypt.encrypt(proto, {key=0x55})
local enc_bc = luac.dump(proto)

print('First 10 bytes (hex):')
for i = 1, math.min(10, #enc_bc) do
    io.write(string.format('%02X ', string.byte(enc_bc, i)))
end
print()
print('First byte:', string.byte(enc_bc, 1), '(0x1B=27 standard, 0x1C=28 encrypted)')

-- 也检查 string.dec 后的原始字节码
local bc2 = string.dec(string.dump(func))
print()
print('Original (string.dec) first byte:', string.byte(bc2, 1))
