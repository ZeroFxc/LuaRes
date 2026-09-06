package.path = package.path .. ";E:/LuaRes/luatools/?.lua"
local luac = require('luac')

local src = "local t={key='value'}; print(t.key)"
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print("main sizecode=", #proto.code)
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local b = luac.GETARG_B(proto.code[i])
    local c = luac.GETARG_C(proto.code[i])
    local opname = luac.OP_NAMES and luac.OP_NAMES[op+1] or tostring(op)
    print(string.format("  [%d] op=%d A=%d B=%d C=%d", i, op, a, b, c))
end
print("constants:")
for i = 1, #proto.k do
    print("  k["..i.."]="..tostring(proto.k[i]))
end
