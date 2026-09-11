package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local src = io.open('utils/ad_test.lua'):read('*a')
local bc = string.dec(string.dump(load(src)), false)

for trial = 1, 10 do
    local p = luac.undump(bc, false)
    luac.num_obfuscate_c(p)
    local e = luac.dump(p)
    local f, lerr = load(e)
    if not f then
        print('trial ' .. trial .. ' LOAD FAIL: ' .. tostring(lerr))
    else
        local old_print = print
        print = function() end
        local ok, err = pcall(f)
        print = old_print
        if not ok then
            print('trial ' .. trial .. ' RUN FAIL: ' .. tostring(err))
        else
            print('trial ' .. trial .. ' OK (code=' .. #p.code .. ' k=' .. #p.k .. ')')
        end
    end
end
