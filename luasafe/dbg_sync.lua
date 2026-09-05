local luac = require("luac")
local src = 'local a = "hello world"; print(a)'
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)
require('str_split').obfuscate(proto)

print("=== code table BEFORE dump ===")
for i=1,#proto.code do
    print(string.format("  [%d] = 0x%08x (op=%d A=%d Bx=%d)",
        i, proto.code[i],
        luac.GET_OPCODE(proto.code[i]),
        luac.GETARG_A(proto.code[i]),
        luac.GETARG_Bx(proto.code[i])))
end

print("\n=== k table BEFORE dump ===")
for i=1,#proto.k do
    print(string.format("  k[%d] = %s", i-1, tostring(proto.k[i])))
end

local enc = luac.dump(proto)
print("\n=== after dump, code table again ===")
for i=1,#proto.code do
    print(string.format("  [%d] = 0x%08x (op=%d A=%d Bx=%d)",
        i, proto.code[i],
        luac.GET_OPCODE(proto.code[i]),
        luac.GETARG_A(proto.code[i]),
        luac.GETARG_Bx(proto.code[i])))
end

local proto2 = luac.undump(enc, false)
print("\n=== reloaded code ===")
for i=1,#proto2.code do
    print(string.format("  [%d] = 0x%08x (op=%d A=%d Bx=%d)",
        i, proto2.code[i],
        luac.GET_OPCODE(proto2.code[i]),
        luac.GETARG_A(proto2.code[i]),
        luac.GETARG_Bx(proto2.code[i])))
end
