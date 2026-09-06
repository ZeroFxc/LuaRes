package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')

local src = 'return function(s) local key=s:byte(1) local r="" for i=2,#s do r=r..string.char(string.byte(s,i)~key) end return r end'
local proto = luac.undump(string.dec(string.dump(load(src))), false)
local dec = proto.p[1]
dec.upvalues[1].instack = 0
dec.upvalues[1].idx = 0

local function enc(s, key)
    local r = string.char(key)
    for i = 1, #s do r = r .. string.char(string.byte(s, i) ~ key) end
    return r
end

local e0 = enc('hello', 106)
local e1 = enc('world', 119)
print('e0 len=' .. #e0 .. ' bytes=' .. table.concat({string.byte(e0,1,#e0)}, ','))
print('e1 len=' .. #e1 .. ' bytes=' .. table.concat({string.byte(e1,1,#e1)}, ','))

local base = luac.undump(string.dec(string.dump(load('local x=1 return x'))), false)
base.p = {dec}
base.k = {e0, e1}
print('base.k[0] len=' .. #base.k[1])
print('base.k[1] len=' .. #base.k[2])

-- 只测试: LOADK R0,K0; LOADK R1,K1; 打印两个寄存器
base.code = {
    luac.CREATE_ABx(1, 0, 0),   -- LOADK R0, K0
    luac.CREATE_ABx(1, 1, 1),   -- LOADK R1, K1
    -- 用 GETTABUP/CALL 打印
    luac.CREATE_ABC(6, 2, 0, 256+0), -- GETTABUP R2, 0, K("print") -- 假设 K2="print"
    luac.CREATE_ABC(36, 2, 3, 1), -- CALL R2, 3, 1 (print(R0, R1))
    luac.CREATE_ABC(38, 0, 1, 0), -- RETURN R0, 1
}
-- 需要把 "print" 加到常量池
base.k = {e0, e1, "print"}
base.maxstacksize = 3
base.numparams = 0
base.is_vararg = 0

print('after setup: base.k[0] len=' .. #base.k[1] .. ' base.k[1] len=' .. #base.k[2])
local ok, r = pcall(function() return load(luac.dump(base))() end)
print('result:', ok, tostring(r))
