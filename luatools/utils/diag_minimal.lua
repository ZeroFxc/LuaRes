package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')

-- 最简解密函数: 只返回 s:sub(2), 无 XOR 无循环
local src = 'return function(s) print("SUB len="..#s) return s:sub(2) end'
local proto = luac.undump(string.dec(string.dump(load(src))), false)
local dec = proto.p[1]
dec.upvalues[1].instack = 0
dec.upvalues[1].idx = 0
print('dec maxstack=' .. dec.maxstacksize .. ' code=' .. #dec.code)

local function enc(s)
    return 'X' .. s  -- 1字节前缀 + 原文
end

local base = luac.undump(string.dec(string.dump(load('local a="hello" local b="world" return a..b'))), false)
base.p = {dec}
base.k = {enc('hello'), enc('world')}
base.code = {
    luac.CREATE_ABx(1, 0, 0),   -- LOADK R0, enc_hello
    luac.CREATE_ABx(44, 2, 0),  -- CLOSURE R2, dec
    luac.CREATE_ABC(0, 3, 0, 0), -- MOVE R3, R0
    luac.CREATE_ABC(36, 2, 2, 2), -- CALL R2, 2, 2
    luac.CREATE_ABC(0, 0, 2, 0), -- MOVE R0, R2
    luac.CREATE_ABx(1, 1, 1),   -- LOADK R1, enc_world
    luac.CREATE_ABx(44, 2, 0),  -- CLOSURE R2, dec
    luac.CREATE_ABC(0, 3, 1, 0), -- MOVE R3, R1
    luac.CREATE_ABC(36, 2, 2, 2), -- CALL R2, 2, 2
    luac.CREATE_ABC(0, 1, 2, 0), -- MOVE R1, R2
    luac.CREATE_ABC(41, 0, 0, 1), -- CONCAT R0, R0, R1
    luac.CREATE_ABC(38, 0, 2, 0), -- RETURN R0, 2
}
base.maxstacksize = 4
local ok, r = pcall(function() return load(luac.dump(base))() end)
print('result:', ok, tostring(r))
