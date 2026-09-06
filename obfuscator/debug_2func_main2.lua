local str_encrypt = require('str_encrypt')
local luac = require('luac')

local src = [[
local function add(a, b) return a + b end
local function greet(name) return "hi " .. name end
local total = 0
for i = 1, 5 do total = add(total, i) end
return greet("x") .. total .. " done"
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
    local opname = ({[0]='MOVE',[1]='LOADK',[5]='GETUPVAL',[13]='ADD',[29]='CONCAT',[30]='JMP',[36]='CALL',[38]='RETURN',[44]='CLOSURE'})[op] or 'OP'..op
    print(string.format('  [%2d] %-10s A=%d B=%d C=%d', i, opname, a, b, c))
end

str_encrypt.encrypt(proto, {key=0x55})

print()
print('=== Encrypted main code ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local b = luac.GETARG_B(proto.code[i])
    local c = luac.GETARG_C(proto.code[i])
    local opname = ({[0]='MOVE',[1]='LOADK',[5]='GETUPVAL',[13]='ADD',[29]='CONCAT',[30]='JMP',[36]='CALL',[38]='RETURN',[44]='CLOSURE'})[op] or 'OP'..op
    print(string.format('  [%2d] %-10s A=%d B=%d C=%d', i, opname, a, b, c))
end
