local luac = require('luac')
local f = io.open('C:/Users/ruilo/Downloads/脱壳.lua', 'rb')
local data = f:read('*a')
f:close()
print('size:', #data, 'first byte:', string.byte(data, 1))

local ok, proto = pcall(luac.undump, data, false)
print('undump ok:', ok)
if ok then
    print('sizecode:', proto.sizecode, 'sizek:', #proto.k, 'sizep:', #proto.p)
    local out = luac.dump(proto)
    print('dump ok, size:', #out)
else
    print('err:', proto)
end
