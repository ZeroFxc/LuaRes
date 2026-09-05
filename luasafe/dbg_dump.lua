local luac = require("luac")
local src = 'local a = "hello world"; print(a)'
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)
require('str_split').obfuscate(proto)
local enc = luac.dump(proto)
-- 打印前64字节的十六进制
io.write("raw bytes (first 80):\n")
for i = 1, math.min(80, #enc) do
    io.write(string.format("%02x ", string.byte(enc, i)))
    if i % 16 == 0 then io.write("\n") end
end
io.write("\n\n")
-- 重新加载并打印指令
local proto2 = luac.undump(enc, false)
print("reloaded code:")
for i=1,#proto2.code do
    local inst = proto2.code[i]
    local op = luac.GET_OPCODE(inst)
    local a = luac.GETARG_A(inst)
    local bx = luac.GETARG_Bx(inst)
    print(string.format("  pc=%d op=%d A=%d Bx=%d (0x%08x)", i-1, op, a, bx, inst))
end
