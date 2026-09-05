local str_encrypt = require('str_encrypt')
local luac = require('luac')

local src = [[
local function greet(name)
    return "hi " .. name
end
return greet("x") .. " y" .. " z"
]]

local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('=== Original constants ===')
for i = 1, #proto.k do
    print('  [' .. i .. ']', type(proto.k[i]), tostring(proto.k[i]))
end

print()
print('=== Original main code ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local b = luac.GETARG_B(proto.code[i])
    local c = luac.GETARG_C(proto.code[i])
    local opname = ({[0]='MOVE',[1]='LOADK',[5]='GETUPVAL',[29]='CONCAT',[36]='CALL',[38]='RETURN',[44]='CLOSURE'})[op] or 'OP'..op
    print(string.format('  [%2d] %-10s A=%d B=%d C=%d', i, opname, a, b, c))
end

print()
print('=== Encrypting... ===')
str_encrypt.encrypt(proto, {key=0x55})

print()
print('=== Encrypted constants ===')
for i = 1, #proto.k do
    print('  [' .. i .. ']', type(proto.k[i]), tostring(proto.k[i]))
end

print()
print('=== Encrypted main code ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local b = luac.GETARG_B(proto.code[i])
    local c = luac.GETARG_C(proto.code[i])
    local opname = ({[0]='MOVE',[1]='LOADK',[5]='GETUPVAL',[29]='CONCAT',[36]='CALL',[38]='RETURN',[44]='CLOSURE'})[op] or 'OP'..op
    print(string.format('  [%2d] %-10s A=%d B=%d C=%d', i, opname, a, b, c))
end

print()
print('=== greet (p[1]) constants ===')
if proto.p and #proto.p > 0 then
    for i = 1, #proto.p[1].k do
        print('  [' .. i .. ']', type(proto.p[1].k[i]), tostring(proto.p[1].k[i]))
    end
end
