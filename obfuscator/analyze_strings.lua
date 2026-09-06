-- 测试字符串在字节码中的存储和引用
local luac = require('luac')

local func = load([[
local s1 = "hello"
local s2 = "world"
local s3 = "test"
print(s1 .. " " .. s2)
local function f()
    return s3 .. "!"
end
return f()
]])

local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('=== Main function ===')
print('sizek:', #proto.k)
for i = 1, #proto.k do
    print(string.format('  k[%d] (%s): %s', i-1, type(proto.k[i]), tostring(proto.k[i])))
end

print()
print('Instructions:')
for i = 1, #proto.code do
    local inst = proto.code[i]
    local op = luac.GET_OPCODE(inst)
    local a = luac.GETARG_A(inst)
    local bx = luac.GETARG_Bx(inst)
    local opname = ({[0]='MOVE',[1]='LOADK',[2]='LOADKX',[3]='LOADBOOL',[4]='LOADNIL',
        [5]='GETUPVAL',[6]='GETTABUP',[7]='GETTABLE',[8]='SETTABUP',[9]='SETUPVAL',
        [10]='SETTABLE',[11]='NEWTABLE',[12]='SELF',[13]='ADD',[14]='SUB',[15]='MUL',
        [16]='MOD',[17]='POW',[18]='DIV',[19]='IDIV',[20]='BAND',[21]='BOR',[22]='BXOR',
        [23]='SHL',[24]='SHR',[25]='UNM',[26]='BNOT',[27]='NOT',[28]='LEN',[29]='CONCAT',
        [30]='JMP',[31]='EQ',[32]='LT',[33]='LE',[34]='TEST',[35]='TESTSET',[36]='CALL',
        [37]='TAILCALL',[38]='RETURN',[39]='FORLOOP',[40]='FORPREP',[41]='TFORCALL',
        [42]='TFORLOOP',[43]='SETLIST',[44]='CLOSURE',[45]='VARARG',[46]='EXTRAARG'})[op] or 'OP'..op
    if op == 1 then -- LOADK
        print(string.format('  [%3d] %-10s A=%d Bx=%d (k[%d]=%s)', i, opname, a, bx, bx, tostring(proto.k[bx+1])))
    elseif op == 6 then -- GETTABUP
        local c = luac.GETARG_C(inst)
        print(string.format('  [%3d] %-10s A=%d B=%d C=%d', i, opname, a, luac.GETARG_B(inst), c))
    else
        print(string.format('  [%3d] %-10s A=%d', i, opname, a))
    end
end

print()
print('=== Sub function ===')
if proto.p and #proto.p > 0 then
    local sub = proto.p[1]
    print('sizek:', #sub.k)
    for i = 1, #sub.k do
        print(string.format('  k[%d] (%s): %s', i-1, type(sub.k[i]), tostring(sub.k[i])))
    end
    print('Instructions:')
    for i = 1, #sub.code do
        local inst = sub.code[i]
        local op = luac.GET_OPCODE(inst)
        local a = luac.GETARG_A(inst)
        if op == 1 then
            local bx = luac.GETARG_Bx(inst)
            print(string.format('  [%3d] LOADK      A=%d Bx=%d (k[%d]=%s)', i, a, bx, bx, tostring(sub.k[bx+1])))
        else
            print(string.format('  [%3d] op=%d     A=%d', i, op, a))
        end
    end
end
