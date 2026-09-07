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

-- Layer 1
local inner1 = VM.exec(vm_chunk)
print('inner1.exec type:', type(inner1.exec))

-- Test: can inner1 execute a simple script that uses closures?
print('--- inner1 closure test ---')
inner1.exec(pack_src([[
local function f() return 99 end
print(f())
]]))

-- Test: can inner1 execute a script that loadfiles?
print('--- inner1 loadfile test ---')
inner1.exec(pack_src([[
local f = loadfile('../luatools/vm_gen.lua')
print('loadfile result:', type(f))
]]))

-- Now try to create layer 2 but with debug
print('--- creating layer 2 ---')
local ok, err = pcall(function()
    return inner1.exec(vm_chunk)
end)
print('layer2 result:', ok, err)
