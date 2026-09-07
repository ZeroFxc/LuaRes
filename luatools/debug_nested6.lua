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

-- Manually create a closure with explicit _ENV and run via inner VM's execute
local chunk = pack_src('print("manual env works")')
local cl = inner1.load(chunk, _G)
print('closure type:', type(cl))

-- Get the raw closure data from closure_map? We can't access it.
-- Instead, just call the closure (which wraps execute)
print('calling closure...')
local ok, err = pcall(cl)
print('result:', ok, err)
