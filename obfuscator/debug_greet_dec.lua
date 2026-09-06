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
str_encrypt.encrypt(proto, {key=0x55})

-- greet 的解密函数
local greet = proto.p[2]
local dec = greet.p[1]

print('=== greet decrypt function ===')
print('sizek:', #dec.k, 'code:', #dec.code, 'maxstack:', dec.maxstacksize)
print('sizeupvalues:', #dec.upvalues)
for i = 1, #dec.upvalues do
    print('  upvalue[' .. i .. ']: instack=' .. tostring(dec.upvalues[i].instack) .. ' idx=' .. tostring(dec.upvalues[i].idx))
end
print('constants:')
for i = 1, #dec.k do
    print('  k[' .. i .. ']:', type(dec.k[i]), tostring(dec.k[i]))
end
print('code:')
for i = 1, #dec.code do
    local op = luac.GET_OPCODE(dec.code[i])
    local a = luac.GETARG_A(dec.code[i])
    local b = luac.GETARG_B(dec.code[i])
    local c = luac.GETARG_C(dec.code[i])
    local opname = ({[0]='MOVE',[1]='LOADK',[5]='GETUPVAL',[6]='GETTABUP',[7]='GETTABLE',[13]='ADD',[22]='BXOR',[27]='NOT',[28]='LEN',[29]='CONCAT',[30]='JMP',[36]='CALL',[38]='RETURN'})[op] or 'OP'..op
    print(string.format('  [%2d] %-10s A=%d B=%d C=%d', i, opname, a, b, c))
end

-- 单独测试解密函数
print()
print('=== Test decrypt function directly ===')
local dec_bc = luac.dump(dec)
print('dec bytecode size:', #dec_bc)
-- 不能直接 load 子 proto，因为它需要 upvalue
