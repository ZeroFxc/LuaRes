local str_encrypt = require('str_encrypt')
local luac = require('luac')

-- 测试：多函数 + for循环 + if
local src = [[
local function is_even(n)
    return n % 2 == 0
end
local total = 0
for i = 1, 10 do
    if is_even(i) then
        total = total + i
    end
end
local msg = "total="
return msg .. total
]]

local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('=== Original ===')
print('main sizek:', #proto.k, 'sizep:', #proto.p)

print()
print('=== Encrypting... ===')
str_encrypt.encrypt(proto, {key=0x55})

local enc_bc = luac.dump(proto)
local ok, f = pcall(load, enc_bc)
if ok then
    local ok2, result = pcall(f)
    print('Result:', tostring(result), '(expected: total=30)')
else
    print('Load failed:', f)
end
