local luac = require("luac")
local f = io.open("flatten_input.luac", "rb")
local bc = f:read("*a")
f:close()
local proto = luac.undump(bc, true)

print("Instructions:")
for i = 1, proto.sizecode do
    local ins = proto.code[i]
    local op = luac.GET_OPCODE(ins)
    local name = luac.OPCODE_NAMES[op+1] or "?"
    local a = luac.GETARG_A(ins)
    local extra = ""
    if op == luac.OP_JMP or op == luac.OP_FORLOOP or op == luac.OP_FORPREP then
        extra = " sBx=" .. luac.GETARG_sBx(ins)
    elseif op == luac.OP_LOADK then
        extra = " Bx=" .. luac.GETARG_Bx(ins)
    elseif op == luac.OP_EQ or op == luac.OP_LT or op == luac.OP_LE then
        extra = string.format(" A=%d B=%d C=%d", a, luac.GETARG_B(ins), luac.GETARG_C(ins))
    end
    print(string.format("  [%2d] %-10s A=%d %s", i, name, a, extra))
end
