local str_split = require('str_split')
local luac = require('luac')
local src = 'print("hello world")'
local proto = luac.undump(string.dec(string.dump(load(src))), false)
str_split.obfuscate(proto)
print('=== main function instructions ===')
local has_call = false
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local names = {[0]='MOVE',[1]='LOADK',[5]='GETUPVAL',[6]='GETTABUP',[7]='GETTABLE',[29]='CONCAT',[36]='CALL',[38]='RETURN'}
    if op == 36 then has_call = true end
    local a = luac.GETARG_A(proto.code[i])
    local b = luac.GETARG_B(proto.code[i])
    local c = luac.GETARG_C(proto.code[i])
    print(string.format('  [%2d] %-10s A=%d B=%d C=%d', i, names[op] or ('OP'..op), a, b, c))
end
print()
print('has CALL instruction:', has_call)
print('constants:')
for i = 1, #proto.k do print('  k['..i..']:', type(proto.k[i]), tostring(proto.k[i])) end
