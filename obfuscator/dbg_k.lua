local luac = require("luac")
local src = 'local a = "hello world"; print(a)'
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print("=== k before str_split ===")
for i=1,#proto.k do print(string.format("  k[%d](lua idx %d) = %s", i-1, i, tostring(proto.k[i]))) end

require('str_split').obfuscate(proto)

print("\n=== k after str_split ===")
for i=1,#proto.k do print(string.format("  k[%d](lua idx %d) = %s", i-1, i, tostring(proto.k[i]))) end

print("\n=== code after str_split ===")
for i=1,#proto.code do
    local inst = proto.code[i]
    print(string.format("  pc=%d op=%d A=%d Bx=%d", i-1, luac.GET_OPCODE(inst), luac.GETARG_A(inst), luac.GETARG_Bx(inst)))
end
