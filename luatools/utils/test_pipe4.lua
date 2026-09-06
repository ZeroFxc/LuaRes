package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local src = io.open('utils/ad_test.lua'):read('*a')
local bc = string.dec(string.dump(load(src)), false)
local mods = {'bool_obfuscate_c','num_obfuscate_c','str_split_c','const_hide_c','str_encrypt_c','const_shuffle_c'}
local access = arg[1] or 'both'
local p = luac.undump(bc, false)
for _, mod in ipairs(mods) do
    io.write(mod .. ' ... ')
    io.flush()
    local ok, err = pcall(luac[mod], p)
    if not ok then io.write('APPLY FAIL\n') break end
    local eok, e = pcall(function() return luac.dump(p) end)
    if not eok then io.write('DUMP FAIL\n') break end
    local f, lerr = load(e)
    if not f then io.write('LOAD FAIL\n') break end
    local old_print = print; print = function() end
    local rok, rerr = pcall(f)
    print = old_print
    if not rok then io.write('RUN FAIL: ' .. tostring(rerr):sub(1,60) .. '\n') break end
    if access == 'k' then local _ = #p.k
    elseif access == 'code' then local _ = #p.code
    else local _ = #p.code; local _ = #p.k end
    io.write('OK\n')
end
print('done')
