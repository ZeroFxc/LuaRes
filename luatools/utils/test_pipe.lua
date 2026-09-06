package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local src = io.open('utils/ad_test.lua'):read('*a')
local bc = string.dec(string.dump(load(src)), false)

local mods = {'bool_obfuscate_c','num_obfuscate_c','str_split_c','const_hide_c','str_encrypt_c','const_shuffle_c','instruction_mutate_c','table_obfuscate_c','opaque_predicate_c','const_poison_c','opaque_junk_c','junk_jmp_c','junk_loadk_c','junk_move_c','op48_junk_c','luac_obfuscate_c','luac_flatten_c','debug_strip_c','antidec_c'}

local p = luac.undump(bc, false)
for _, mod in ipairs(mods) do
    if luac[mod] then
        io.write(mod .. ' ... ')
        io.flush()
        local ok, err = pcall(luac[mod], p)
        if not ok then io.write('APPLY FAIL: ' .. tostring(err):sub(1,60) .. '\n') break end
        local eok, e = pcall(function() return luac.dump(p) end)
        if not eok then io.write('DUMP FAIL\n') break end
        local f, lerr = load(e)
        if not f then io.write('LOAD FAIL: ' .. tostring(lerr):sub(1,40) .. '\n') break end
        local old_print = print; print = function() end
        local rok, rerr = pcall(f)
        print = old_print
        if not rok then io.write('RUN FAIL: ' .. tostring(rerr):sub(1,60) .. '\n') break end
        io.write('OK (code=' .. #p.code .. ' k=' .. #p.k .. ')\n')
    end
end
print('done')
