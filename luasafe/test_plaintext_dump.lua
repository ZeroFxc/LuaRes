local func = load('local s = "hello world"; return s')
local bc = string.dump(func)
print('dump size:', #bc)
-- 搜索 'hello' 字符串
local pos = string.find(bc, 'hello')
if pos then
    print('Found plaintext hello at pos', pos)
else
    print('plaintext hello NOT found')
end
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
