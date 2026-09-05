local str_encrypt = require('str_encrypt')
local luac = require('luac')

local func2 = load([[
local s1 = "hello"
local s2 = "world"
local s3 = "test"
return s1 .. " " .. s2 .. " " .. s3
]])
local bc2 = string.dec(string.dump(func2))
local proto2 = luac.undump(bc2, false)

print('=== Original code ===')
print('maxstacksize:', proto2.maxstacksize)
for i = 1, #proto2.code do
    local inst = proto2.code[i]
    local op = luac.GET_OPCODE(inst)
    local a = luac.GETARG_A(inst)
    local opname = ({[0]='MOVE',[1]='LOADK',[2]='LOADKX',[3]='LOADBOOL',[4]='LOADNIL',
        [5]='GETUPVAL',[6]='GETTABUP',[7]='GETTABLE',[8]='SETTABUP',[9]='SETUPVAL',
        [10]='SETTABLE',[11]='NEWTABLE',[12]='SELF',[13]='ADD',[14]='SUB',[15]='MUL',
        [16]='MOD',[17]='POW',[18]='DIV',[19]='IDIV',[20]='BAND',[21]='BOR',[22]='BXOR',
        [23]='SHL',[24]='SHR',[25]='UNM',[26]='BNOT',[27]='NOT',[28]='LEN',[29]='CONCAT',
        [30]='JMP',[31]='EQ',[32]='LT',[33]='LE',[34]='TEST',[35]='TESTSET',[36]='CALL',
        [37]='TAILCALL',[38]='RETURN',[39]='FORLOOP',[40]='FORPREP',[41]='TFORCALL',
        [42]='TFORLOOP',[43]='SETLIST',[44]='CLOSURE',[45]='VARARG',[46]='EXTRAARG'})[op] or 'OP'..op
    if op == 1 then
        local bx = luac.GETARG_Bx(inst)
        print(string.format('  [%3d] %-10s A=%d Bx=%d (k[%d]=%s)', i, opname, a, bx, bx, tostring(proto2.k[bx+1])))
    elseif op == 29 then
        local b = luac.GETARG_B(inst)
        local c = luac.GETARG_C(inst)
        print(string.format('  [%3d] %-10s A=%d B=%d C=%d', i, opname, a, b, c))
    else
        print(string.format('  [%3d] %-10s A=%d', i, opname, a))
    end
end

print()
print('=== Encrypting... ===')
str_encrypt.encrypt(proto2, {key = 0xAA})

print()
print('=== Encrypted code ===')
print('maxstacksize:', proto2.maxstacksize)
print('sizep:', #proto2.p)
for i = 1, math.min(30, #proto2.code) do
    local inst = proto2.code[i]
    local op = luac.GET_OPCODE(inst)
    local a = luac.GETARG_A(inst)
    local opname = ({[0]='MOVE',[1]='LOADK',[2]='LOADKX',[3]='LOADBOOL',[4]='LOADNIL',
        [5]='GETUPVAL',[6]='GETTABUP',[7]='GETTABLE',[8]='SETTABUP',[9]='SETUPVAL',
        [10]='SETTABLE',[11]='NEWTABLE',[12]='SELF',[13]='ADD',[14]='SUB',[15]='MUL',
        [16]='MOD',[17]='POW',[18]='DIV',[19]='IDIV',[20]='BAND',[21]='BOR',[22]='BXOR',
        [23]='SHL',[24]='SHR',[25]='UNM',[26]='BNOT',[27]='NOT',[28]='LEN',[29]='CONCAT',
        [30]='JMP',[31]='EQ',[32]='LT',[33]='LE',[34]='TEST',[35]='TESTSET',[36]='CALL',
        [37]='TAILCALL',[38]='RETURN',[39]='FORLOOP',[40]='FORPREP',[41]='TFORCALL',
        [42]='TFORLOOP',[43]='SETLIST',[44]='CLOSURE',[45]='VARARG',[46]='EXTRAARG'})[op] or 'OP'..op
    if op == 1 then
        local bx = luac.GETARG_Bx(inst)
        print(string.format('  [%3d] %-10s A=%d Bx=%d', i, opname, a, bx))
    elseif op == 30 then
        local sbx = luac.GETARG_sBx(inst)
        print(string.format('  [%3d] %-10s sBx=%d (target=%d)', i, opname, sbx, i + sbx + 1))
    elseif op == 36 or op == 37 then
        local b = luac.GETARG_B(inst)
        local c = luac.GETARG_C(inst)
        print(string.format('  [%3d] %-10s A=%d B=%d C=%d', i, opname, a, b, c))
    else
        print(string.format('  [%3d] %-10s A=%d', i, opname, a))
    end
end
