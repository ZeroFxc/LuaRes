local func = load('local s = "hello world"; return s')
local bc_enc = string.dump(func)
print('encoded dump size:', #bc_enc)
local bc = string.dec(bc_enc)
print('decoded dump size:', #bc)
-- 搜索 'hello' 字符串
local pos = string.find(bc, 'hello')
if pos then
    print('Found plaintext hello at pos', pos)
else
    print('plaintext hello NOT found')
end
-- 打印前 50 字节
print('First 50 bytes:')
for i = 1, math.min(50, #bc) do
    io.write(string.format('%02X ', bc:byte(i)))
    if i % 16 == 0 then io.write('\n') end
end
io.write('\n')
-- 用 luaclib 解析
local luac = require('luac')
local proto = luac.undump(bc, false)
print('constants:')
for i = 1, #proto.k do
    print('  [' .. i .. ']', type(proto.k[i]), tostring(proto.k[i]))
end
-- 测试运行
local f = load(bc)
print('result:', f())
