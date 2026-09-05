local str_encrypt = require('str_encrypt')
local luac = require('luac')

local src = [[
local function factorial(n)
    if n <= 1 then return 1 end
    return n * factorial(n - 1)
end
local function is_even(n)
    return n % 2 == 0
end
local function greet(name)
    return "hello, " .. name .. "!"
end
local total = 0
for i = 1, 10 do
    if is_even(i) then total = total + i end
end
local msg = greet("world")
local fact = factorial(5)
return msg .. " total=" .. total .. " fact=" .. fact
]]

local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('=== Original main JMP ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    if op == 30 then  -- JMP
        local a = luac.GETARG_A(proto.code[i])
        local sbx = luac.GETARG_sBx(proto.code[i])
        print(string.format('  [%d] JMP A=%d sBx=%d -> target=%d', i, a, sbx, i + sbx + 1))
    end
end

print()
print('=== Encrypting... ===')
str_encrypt.encrypt(proto, {key=0x55})

print()
print('=== Encrypted main JMP ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    if op == 30 then  -- JMP
        local a = luac.GETARG_A(proto.code[i])
        local sbx = luac.GETARG_sBx(proto.code[i])
        print(string.format('  [%d] JMP A=%d sBx=%d -> target=%d', i, a, sbx, i + sbx + 1))
    end
end

print()
print('=== Encrypted main full code ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local opname = ({[0]='MOVE',[1]='LOADK',[3]='LOADBOOL',[5]='GETUPVAL',[11]='NEWTABLE',[12]='SETLIST',[13]='ADD',[14]='SUB',[15]='MUL',[19]='MOD',[27]='NOT',[29]='CONCAT',[30]='JMP',[31]='EQ',[32]='LT',[33]='LE',[34]='TEST',[36]='CALL',[37]='TAILCALL',[38]='RETURN',[44]='CLOSURE',[45]='VARARG'})[op] or 'OP'..op
    local extra = ''
    if op == 30 then
        local sbx = luac.GETARG_sBx(proto.code[i])
        extra = string.format(' sBx=%d -> %d', sbx, i + sbx + 1)
    elseif op == 1 then
        local bx = luac.GETARG_Bx(proto.code[i])
        extra = string.format(' Bx=%d', bx)
    elseif op == 36 or op == 37 then
        local b = luac.GETARG_B(proto.code[i])
        local c = luac.GETARG_C(proto.code[i])
        extra = string.format(' B=%d C=%d', b, c)
    end
    print(string.format('  [%2d] %-10s A=%d%s', i, opname, a, extra))
end
