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

print('=== Before encrypt ===')
print('main sizep:', #proto.p)
for i = 1, #proto.p do
    print(string.format('  p[%d]: sizek=%d code=%d sizep=%d sizeupvalues=%d', i, #proto.p[i].k, #proto.p[i].code, #proto.p[i].p, #proto.p[i].upvalues))
end

print()
print('=== Encrypting all ===')
str_encrypt.encrypt(proto, {key=0x55})

print()
print('=== After encrypt ===')
print('main sizep:', #proto.p)
for i = 1, #proto.p do
    print(string.format('  p[%d]: sizek=%d code=%d sizep=%d sizeupvalues=%d', i, #proto.p[i].k, #proto.p[i].code, #proto.p[i].p, #proto.p[i].upvalues))
    if #proto.p[i].upvalues > 0 then
        for j = 1, #proto.p[i].upvalues do
            print(string.format('    upvalue[%d]: instack=%s idx=%s', j, tostring(proto.p[i].upvalues[j].instack), tostring(proto.p[i].upvalues[j].idx)))
        end
    end
end

-- 检查 greet (p[2]) 的解密函数
if #proto.p >= 2 and #proto.p[2].p > 0 then
    local dec = proto.p[2].p[1]
    print()
    print('greet decrypt func: sizek=' .. #dec.k .. ' code=' .. #dec.code)
    print('  sizeupvalues=' .. #dec.upvalues)
    if #dec.upvalues > 0 then
        for j = 1, #dec.upvalues do
            print(string.format('    upvalue[%d]: instack=%s idx=%s', j, tostring(dec.upvalues[j].instack), tostring(dec.upvalues[j].idx)))
        end
    end
    print('  first 5 instructions:')
    for i = 1, math.min(5, #dec.code) do
        local op = luac.GET_OPCODE(dec.code[i])
        print(string.format('    [%d] op=%d A=%d', i, op, luac.GETARG_A(dec.code[i])))
    end
end
