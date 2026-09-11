package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')

local src = io.open('utils/ad_test.lua', 'rb'):read('*a')
local bc = string.dec(string.dump(load(src)))

local function test_module(name, fn)
    local p = luac.undump(bc, false)
    local ok, r = pcall(fn, p)
    if not ok then
        print(name .. ': CALL FAILED: ' .. tostring(r):sub(1,200))
        return
    end
    local enc = luac.dump(p)
    local f, lerr = load(enc)
    if not f then
        print(name .. ': LOAD FAILED: ' .. tostring(lerr):sub(1,200))
        return
    end
    local old_print = print
    print = function() end
    local rok, rerr = pcall(f)
    print = old_print
    if not rok then
        print(name .. ': RUN FAILED: ' .. tostring(rerr):sub(1,200))
        return
    end
    print(name .. ': OK (code=' .. #p.code .. ')')
end

test_module('str_split_c', function(p) luac.str_split_c(p) end)
test_module('opaque_junk_c', function(p) luac.opaque_junk_c(p, {count=10}) end)
test_module('luac_obfuscate_c', function(p) luac.luac_obfuscate_c(p) end)
test_module('luac_flatten_c', function(p) luac.luac_flatten_c(p) end)
test_module('opaque_predicate_c(fixed)', function(p) luac.opaque_predicate_c(p) end)
print('done')
