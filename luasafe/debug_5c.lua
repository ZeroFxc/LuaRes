local str_encrypt = require('str_encrypt')
local luac = require('luac')

local src = [[
local function factorial(n)
    if n <= 1 then return 1 end
    return n * factorial(n - 1)
end
local function greet(name)
    return "hello, " .. name .. "!"
end
local msg = greet("world")
local fact = factorial(5)
return msg .. " total=" .. 30 .. " fact=" .. fact
]]

local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('=== Original main code ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local b = luac.GETARG_B(proto.code[i])
    local c = luac.GETARG_C(proto.code[i])
    local opname = ({[0]='MOVE',[1]='LOADK',[5]='GETUPVAL',[13]='ADD',[14]='SUB',[15]='MUL',[29]='CONCAT',[30]='JMP',[33]='LE',[34]='TEST',[36]='CALL',[38]='RETURN',[44]='CLOSURE'})[op] or 'OP'..op
    print(string.format('  [%2d] %-10s A=%d B=%d C=%d', i, opname, a, b, c))
end

print()
print('=== Encrypting... ===')
str_encrypt.encrypt(proto, {key=0x55})

print()
print('=== Encrypted main code ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local b = luac.GETARG_B(proto.code[i])
    local c = luac.GETARG_C(proto.code[i])
    local opname = ({[0]='MOVE',[1]='LOADK',[5]='GETUPVAL',[13]='ADD',[14]='SUB',[15]='MUL',[29]='CONCAT',[30]='JMP',[33]='LE',[34]='TEST',[36]='CALL',[38]='RETURN',[44]='CLOSURE'})[op] or 'OP'..op
    print(string.format('  [%2d] %-10s A=%d B=%d C=%d', i, opname, a, b, c))
end
