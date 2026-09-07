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

local function pack_src(src)
    local f = load(src)
    local bc = string.dec(string.dump(f, true))
    local proto = luac.undump(bc, true)
    return vm_pack.pack(proto)
end

local vm_chunk = pack_vm_source()
local inner1 = VM.exec(vm_chunk)

-- Test 1: return arithmetic (no _ENV needed)
print('test1:', inner1.exec(pack_src('return 1+2')))

-- Test 2: call print (needs _ENV)
print('test2:')
local ok, err = pcall(function() inner1.exec(pack_src('print("hello from inner")')) end)
print('  ok:', ok, 'err:', err)

-- Test 3: return a table (needs NEWTABLE but no _ENV)
print('test3:')
local ok3, r3 = pcall(function() return inner1.exec(pack_src('return {a=1}')) end)
print('  ok:', ok3, 'result:', type(r3))
if type(r3) == 'table' then print('  r3.a:', r3.a) end
