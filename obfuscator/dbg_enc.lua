local luac = require('luac')
local f = load('local a = "hello"; print(a)')
local bc = string.dec(string.dump(f))
print('bytecode first byte: 0x' .. string.format('%02x', bc:byte(1)))
local proto = luac.undump(bc, false)
print('constants:')
for i=1,#proto.k do print(string.format('  k[%d] = %s', i-1, tostring(proto.k[i]))) end
