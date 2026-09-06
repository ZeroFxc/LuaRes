local luac = require('luac')
local func = load('local s = " "; return s')
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)
print('constants:')
for i = 1, #proto.k do
    local v = proto.k[i]
    print('  [' .. i .. '] type=' .. type(v) .. ' len=' .. #tostring(v) .. ' byte1=' .. string.byte(tostring(v), 1))
end
local f = load(bc)
local r = f()
print('result len=' .. #r .. ' byte1=' .. string.byte(r, 1))
