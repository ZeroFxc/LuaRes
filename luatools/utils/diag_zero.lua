package.path = package.path .. ';E:/LuaRes/luatools/utils/?.lua'
local luac = require('luac')

-- 构造一个含 0 字节的字符串常量, dump -> undump, 检查是否被截断
local proto = luac.undump(string.dec(string.dump(load('local x=1 return x'))), false)
local s_with_zero = string.char(119, 0, 24, 5, 27, 19)  -- 6 bytes, has 0 at pos 2
local s_no_zero = string.char(106, 2, 15, 6, 6, 5)  -- 6 bytes, no 0
print('before dump: with_zero len=' .. #s_with_zero .. ' no_zero len=' .. #s_no_zero)

proto.k = {s_with_zero, s_no_zero}
proto.code = {
    luac.CREATE_ABx(1, 0, 0),  -- LOADK R0, K0
    luac.CREATE_ABx(1, 1, 1),  -- LOADK R1, K1
    luac.CREATE_ABC(38, 0, 1, 0),  -- RETURN R0, 1 (return R0, but we'll check both)
}
proto.maxstacksize = 2

local bc = luac.dump(proto)
print('dump size: ' .. #bc)
local proto2 = luac.undump(bc, false)
print('after undump: K0 len=' .. #proto2.k[1] .. ' K1 len=' .. #proto2.k[2])
print('K0 bytes: ' .. table.concat({string.byte(proto2.k[1], 1, #proto2.k[1])}, ','))
print('K1 bytes: ' .. table.concat({string.byte(proto2.k[2], 1, #proto2.k[2])}, ','))
