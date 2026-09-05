local luac = require("luac")
local f = io.open('flatten_output.luac', 'rb')
local bc = f:read('*a')
f:close()
local proto = luac.undump(bc, false)
print("Flattened instructions (sizecode from table = " .. #proto.code .. "):")
for i = 1, #proto.code do
    local ins = proto.code[i]
    local op = luac.GET_OPCODE(ins)
    local name = luac.OPCODE_NAMES[op+1] or "?"
    local a = luac.GETARG_A(ins)
    local extra = ""
    if op == luac.OP_JMP then
        extra = " sBx=" .. luac.GETARG_sBx(ins)
    elseif op == luac.OP_LOADK then
        extra = " Bx=" .. luac.GETARG_Bx(ins)
    elseif op == luac.OP_EQ or op == luac.OP_LT or op == luac.OP_LE then
        extra = string.format(" A=%d B=%d C=%d", a, luac.GETARG_B(ins), luac.GETARG_C(ins))
    elseif op == luac.OP_RETURN then
        extra = string.format(" A=%d B=%d", a, luac.GETARG_B(ins))
    end
    print(string.format("  [%2d] %-10s %s", i, name, extra))
end
print("\nConstants:")
for i = 1, #proto.k do
    print(string.format("  [%d] %s", i-1, tostring(proto.k[i])))
end
