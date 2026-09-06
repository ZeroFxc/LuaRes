local luac = require("luac")
local src = 'local a = "hello world"; print(a)'
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print("=== BEFORE ===")
print("constants:")
for i=1,#proto.k do print(string.format("  k[%d] = %s (%s)", i-1, tostring(proto.k[i]), type(proto.k[i]))) end
print("code:")
for i=1,#proto.code do
    local inst = proto.code[i]
    local op = luac.GET_OPCODE(inst)
    local a = luac.GETARG_A(inst)
    local bx = luac.GETARG_Bx(inst)
    local b = luac.GETARG_B(inst)
    local c = luac.GETARG_C(inst)
    print(string.format("  pc=%d op=%d A=%d B=%d C=%d Bx=%d", i-1, op, a, b, c, bx))
end

require('str_split').obfuscate(proto)

print("\n=== AFTER str_split ===")
print("constants:")
for i=1,#proto.k do print(string.format("  k[%d] = %s (%s)", i-1, tostring(proto.k[i]), type(proto.k[i]))) end
print("code:")
for i=1,#proto.code do
    local inst = proto.code[i]
    local op = luac.GET_OPCODE(inst)
    local a = luac.GETARG_A(inst)
    local bx = luac.GETARG_Bx(inst)
    local b = luac.GETARG_B(inst)
    local c = luac.GETARG_C(inst)
    print(string.format("  pc=%d op=%d A=%d B=%d C=%d Bx=%d", i-1, op, a, b, c, bx))
end
