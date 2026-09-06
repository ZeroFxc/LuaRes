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

print('=== Original main full code ===')
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local opname = ({[0]='MOVE',[1]='LOADK',[2]='LOADKX',[3]='LOADBOOL',[4]='LOADNIL',[5]='GETUPVAL',[6]='GETTABUP',[7]='GETTABLE',[8]='SETTABUP',[9]='SETUPVAL',[10]='SETTABLE',[11]='NEWTABLE',[12]='SELF',[13]='ADD',[14]='SUB',[15]='MUL',[16]='MOD',[17]='POW',[18]='DIV',[19]='IDIV',[20]='BAND',[21]='BOR',[22]='BXOR',[23]='SHL',[24]='SHR',[25]='UNM',[26]='BNOT',[27]='NOT',[28]='LEN',[29]='CONCAT',[30]='JMP',[31]='EQ',[32]='LT',[33]='LE',[34]='TEST',[35]='TESTSET',[36]='CALL',[37]='TAILCALL',[38]='RETURN',[39]='VARARG',[40]='EXTRAARG',[44]='CLOSURE'})[op] or 'OP'..op
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
