package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')

-- 带调试输出的解密函数
local src = [[
return function(s)
    local key = s:byte(1)
    local r = ""
    for i = 2, #s do
        r = r .. string.char(string.byte(s, i) ~ key)
    end
    print("DEC len=" .. #s .. " key=" .. key .. " result=" .. r)
    return r
end
]]
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)
local dec = proto.p[1]
dec.upvalues[1].instack = 0
dec.upvalues[1].idx = 0

-- 用 str_encrypt 的方式构造测试
local function enc(s, key)
    local r = string.char(key)
    for i = 1, #s do r = r .. string.char(string.byte(s, i) ~ key) end
    return r
end

-- 用一个简单的非 vararg 基类
local base = luac.undump(string.dec(string.dump(load('local x=1 return x'))), false)
base.p = {dec}
base.k = {enc('hello', 106), enc('world', 119)}
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
base.numparams = 0
base.is_vararg = 0

local ok, r = pcall(function() return load(luac.dump(base))() end)
print('result:', ok, tostring(r))
