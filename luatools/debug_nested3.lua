package.path = '../luatools/?.lua;' .. package.path
local VM = require('vm_gen')
local luac = require('luac')
local vm_pack = require('forward.vm_pack')

local function pack_vm_source()
    local f = loadfile('../luatools/vm_gen.lua')
    local bc = string.dec(string.dump(f, true))
    local proto = luac.undump(bc, true)
    return vm_pack.pack(proto)
end

local vm_chunk = pack_vm_source()
local inner1 = VM.exec(vm_chunk)

print('inner1:', type(inner1))
print('inner1.load:', type(inner1.load))
print('inner1.exec:', type(inner1.exec))
print('inner1.run:', type(inner1.run))
print('inner1.pack:', type(inner1.pack))

-- Try calling VM.load directly
local chunk = vm_pack.pack(luac.undump(string.dec(string.dump(load('return 1')), true), true))
print('chunk type:', type(chunk))

local ok, cl = pcall(inner1.load, chunk)
print('inner1.load result:', ok, type(cl))
if ok then
    print('  closure type:', type(cl))
    -- Try calling the closure
    local ok2, r = pcall(cl)
    print('  closure call:', ok2, r)
end
