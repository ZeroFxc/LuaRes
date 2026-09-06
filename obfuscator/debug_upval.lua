local luac = require('luac')

local src = [[
local function greet(name)
    return "hello, " .. name
end
return greet("world")
]]

local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('main sizeupvalues:', proto.sizeupvalues or #proto.upvalues)
if proto.upvalues then
    for i = 1, #proto.upvalues do
        print('  main upvalue[' .. i .. ']: instack=' .. tostring(proto.upvalues[i].instack) .. ' idx=' .. tostring(proto.upvalues[i].idx))
    end
end

if proto.p and #proto.p > 0 then
    local greet = proto.p[1]
    print('greet sizeupvalues:', greet.sizeupvalues or #greet.upvalues)
    if greet.upvalues then
        for i = 1, #greet.upvalues do
            print('  greet upvalue[' .. i .. ']: instack=' .. tostring(greet.upvalues[i].instack) .. ' idx=' .. tostring(greet.upvalues[i].idx))
        end
    else
        print('  greet has NO upvalues!')
    end
end
