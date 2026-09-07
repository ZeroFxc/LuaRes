package.path = '../luatools/?.lua;' .. package.path
local VM = require('vm_gen')
local luac = require('luac')
local vm_pack = require('forward.vm_pack')

local function pack_src(src)
    local f = load(src)
    local bc = string.dec(string.dump(f, true))
    local proto = luac.undump(bc, true)
    return vm_pack.pack(proto)
end

local function pack_vm_source()
    local f = loadfile('../luatools/vm_gen.lua')
    local bc = string.dec(string.dump(f, true))
    local proto = luac.undump(bc, true)
    return vm_pack.pack(proto)
end

local vm_chunk = pack_vm_source()
local inner1 = VM.exec(vm_chunk)

-- Test: simple table access (no closure)
print('--- table test ---')
inner1.exec(pack_src('local t = {a=1}; print(t.a)'))

-- Test: simple function call (no closure creation)
print('--- function call test ---')
inner1.exec(pack_src('print(type(42))'))

-- Test: create a closure but don't call it
print('--- closure create test ---')
inner1.exec(pack_src('local f = function() return 1 end; print("created", type(f))'))
