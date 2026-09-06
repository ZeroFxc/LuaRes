package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local str_encrypt = require('str_encrypt')

local src = 'local t={v=10} function t:f(n) return self.v+n end return t:f(5)'
local proto = luac.undump(string.dec(string.dump(load(src))), false)

print("=== BEFORE ===")
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local b = luac.GETARG_B(proto.code[i])
    local c = luac.GETARG_C(proto.code[i])
    local bx = luac.GETARG_Bx(proto.code[i])
    print(string.format("%3d: op=%d A=%d B=%d C=%d Bx=%d", i, op, a, b, c, bx))
end

str_encrypt.encrypt_function(proto, {})

print("=== AFTER str_encrypt ===")
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local b = luac.GETARG_B(proto.code[i])
    local c = luac.GETARG_C(proto.code[i])
    local bx = luac.GETARG_Bx(proto.code[i])
    local desc = string.format("%3d: op=%d A=%d B=%d C=%d Bx=%d", i, op, a, b, c, bx)
    if op == 1 then desc = desc .. " LOADK K" .. bx end
    if op == 12 then desc = desc .. " SELF" end
    if op == 36 then desc = desc .. " CALL" end
    if op == 44 then desc = desc .. " CLOSURE p" .. bx end
    print(desc)
end

print("=== constants ===")
for i = 1, #proto.k do
    local v = proto.k[i]
    if type(v) == 'string' then
        print(string.format("K%d: string len=%d bytes=%s", i-1, #v, table.concat({string.byte(v, 1, math.min(#v, 20))}, ',')))
    else
        print(string.format("K%d: %s = %s", i-1, type(v), tostring(v)))
    end
end

print("=== sub-protos ===")
for i = 1, #proto.p do
    print(string.format("p%d: code=%d maxstack=%d", i-1, #proto.p[i].code, proto.p[i].maxstacksize))
end
