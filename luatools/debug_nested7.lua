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

-- Test: inner VM runs a script that returns _G
local chunk = pack_src('return _G')
local g = inner1.exec(chunk)
print('inner _G:', type(g), g)
if type(g) == 'table' then
    print('  _G.print:', type(g.print))
    print('  _G._G:', type(g._G))
end

-- Test: inner VM runs a script that returns its _ENV via debug
local chunk2 = pack_src([[
local function getenv()
    local i = 1
    while true do
        local n, v = debug.getlocal(1, i)
        if not n then break end
        if n == 'env' or n == '_ENV' then return v end
        i = i + 1
    end
    return nil
end
return getenv()
]])
local env = inner1.exec(chunk2)
print('inner env:', type(env))
