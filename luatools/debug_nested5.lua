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

-- Test: can inner VM access _G?
print('--- _G access test ---')
inner1.exec(pack_src([[
local g = _G
print("_G type:", type(g))
print("print type:", type(print))
]]))

-- Test: pass explicit env to VM.load
print('--- explicit env test ---')
local chunk = pack_src('print("explicit env works")')
local cl = inner1.load(chunk, _G)
cl()
