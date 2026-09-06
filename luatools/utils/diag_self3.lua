package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local se = require('str_encrypt')
local de = require('destr_encrypt')

local src = 'local t={v=10} function t:f(n) return self.v+n end return t:f(5)'
local proto = luac.undump(string.dec(string.dump(load(src))), false)

-- Dump sub-proto before
print("=== SUB-PROTO (t:f) BEFORE encrypt ===")
local sp = proto.p[1]
for i = 1, #sp.code do
    local op = luac.GET_OPCODE(sp.code[i])
    local a = luac.GETARG_A(sp.code[i])
    local b = luac.GETARG_B(sp.code[i])
    local c = luac.GETARG_C(sp.code[i])
    local bx = luac.GETARG_Bx(sp.code[i])
    print(string.format("%3d: op=%d A=%d B=%d C=%d Bx=%d", i, op, a, b, c, bx))
end
print("sub constants:")
for i = 1, #sp.k do print(string.format("  K%d: %s = %s", i-1, type(sp.k[i]), tostring(sp.k[i]))) end

se.encrypt(proto, {})
print("\n=== SUB-PROTO AFTER encrypt ===")
sp = proto.p[1]
for i = 1, #sp.code do
    local op = luac.GET_OPCODE(sp.code[i])
    local a = luac.GETARG_A(sp.code[i])
    local b = luac.GETARG_B(sp.code[i])
    local c = luac.GETARG_C(sp.code[i])
    local bx = luac.GETARG_Bx(sp.code[i])
    local desc = string.format("%3d: op=%d A=%d B=%d C=%d", i, op, a, b, c)
    if op == 1 then desc = desc .. " LOADK K" .. bx end
    if op == 6 then desc = desc .. " GETTABUP" end
    if op == 7 then desc = desc .. " GETTABLE" end
    if op == 36 then desc = desc .. " CALL" end
    if op == 44 then desc = desc .. " CLOSURE p" .. bx end
    print(desc)
end
print("sub constants:")
for i = 1, #sp.k do
    local v = sp.k[i]
    if type(v) == 'string' then
        print(string.format("  K%d: string len=%d bytes=%s", i-1, #v, table.concat({string.byte(v,1,math.min(#v,10))},',')))
    else
        print(string.format("  K%d: %s = %s", i-1, type(v), tostring(v)))
    end
end
print("sub sub-protos: " .. #sp.p)

de.clean(proto)
print("\n=== SUB-PROTO AFTER reverse ===")
sp = proto.p[1]
for i = 1, #sp.code do
    local op = luac.GET_OPCODE(sp.code[i])
    local a = luac.GETARG_A(sp.code[i])
    local b = luac.GETARG_B(sp.code[i])
    local c = luac.GETARG_C(sp.code[i])
    print(string.format("%3d: op=%d A=%d B=%d C=%d", i, op, a, b, c))
end
print("sub constants:")
for i = 1, #sp.k do print(string.format("  K%d: %s = %s", i-1, type(sp.k[i]), tostring(sp.k[i]))) end

local ok, r = pcall(function() return load(luac.dump(proto))() end)
print("\n=== EXECUTE: ok=" .. tostring(ok) .. " result=" .. tostring(r))
