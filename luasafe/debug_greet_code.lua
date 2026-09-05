local str_encrypt = require('str_encrypt')
local luac = require('luac')

local src = [[
local function add(a, b) return a + b end
local function greet(name)
    return "hello, " .. name .. "!"
end
local total = 0
for i = 1, 10 do total = add(total, i) end
local msg = greet("world")
return msg .. " t=" .. total .. " end"
]]

local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

str_encrypt.encrypt(proto, {key=0x55})

print('=== greet (p[2]) full code ===')
local greet = proto.p[2]
for i = 1, #greet.code do
    local op = luac.GET_OPCODE(greet.code[i])
    local a = luac.GETARG_A(greet.code[i])
    local b = luac.GETARG_B(greet.code[i])
    local c = luac.GETARG_C(greet.code[i])
    local opname = ({[0]='MOVE',[1]='LOADK',[5]='GETUPVAL',[29]='CONCAT',[36]='CALL',[38]='RETURN',[44]='CLOSURE'})[op] or 'OP'..op
    print(string.format('  [%2d] %-10s A=%d B=%d C=%d', i, opname, a, b, c))
end
print('greet maxstacksize:', greet.maxstacksize)
print('greet sizep:', #greet.p)
