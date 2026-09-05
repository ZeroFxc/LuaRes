local luac = require("luac")
-- LOADK R8, k8
local ins = luac.CREATE_ABx(luac.OP_LOADK, 8, 8)
print(string.format("ins = %d (0x%08x)", ins, ins))
print("op =", luac.GET_OPCODE(ins))
print("A =", luac.GETARG_A(ins))
print("Bx =", luac.GETARG_Bx(ins))
print("B =", luac.GETARG_B(ins))
print("C =", luac.GETARG_C(ins))
-- 手动解码
local op = ins % 64
local a = math.floor(ins / 64) % 256
local bx = math.floor(ins / 16384)
print(string.format("manual: op=%d A=%d Bx=%d", op, a, bx))
