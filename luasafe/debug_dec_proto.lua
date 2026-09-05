local luac = require('luac')

-- 编译解密函数
local src = [[
return function(s)
    local r = ""
    for i = 1, #s do
        r = r .. string.char(string.byte(s, i) ~ 0x55)
    end
    return r
end
]]
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('Main proto:')
print('  sizeupvalues:', proto.sizeupvalues or #proto.upvalues)
print('  sizep:', #proto.p)
if proto.upvalues then
    for i = 1, #proto.upvalues do
        print('  upvalue[' .. i .. ']:', proto.upvalues[i].instack, proto.upvalues[i].idx)
    end
end

print()
if proto.p and #proto.p > 0 then
    local sub = proto.p[1]
    print('Sub proto (decrypt function):')
    print('  sizeupvalues:', sub.sizeupvalues or #sub.upvalues)
    print('  sizek:', #sub.k)
    print('  code size:', #sub.code)
    if sub.upvalues then
        for i = 1, #sub.upvalues do
            print('  upvalue[' .. i .. ']: instack=' .. tostring(sub.upvalues[i].instack) .. ' idx=' .. tostring(sub.upvalues[i].idx))
        end
    end
    print('  First 10 instructions:')
    for i = 1, math.min(10, #sub.code) do
        local op = luac.GET_OPCODE(sub.code[i])
        local a = luac.GETARG_A(sub.code[i])
        print(string.format('    [%d] op=%d A=%d', i, op, a))
    end
end
