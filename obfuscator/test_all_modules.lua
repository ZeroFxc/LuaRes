package.path = package.path .. ';E:/LuaRes/luatools/forward/?.lua'
local luac = require('luac')

local modules = {
    'bool_obfuscate', 'num_obfuscate', 'str_split', 'str_encrypt',
    'const_shuffle', 'instruction_mutate', 'opaque_predicate', 'const_poison',
    'opaque_junk', 'junk_jmp', 'junk_loadk', 'junk_move', 'op48_junk',
    'luac_obfuscate', 'luac_flatten', 'debug_strip', 'antidec'
}

local f = io.open('E:/LuaRes/tk.lua', 'rb')
local data = f:read('*a')
f:close()
print('input size:', #data)

for _, name in ipairs(modules) do
    local ok_mod, mod = pcall(require, name)
    if not ok_mod then
        print(string.format('%-20s LOAD_FAIL: %s', name, tostring(mod)))
        goto continue
    end
    
    -- 重新 undump（每个模块用干净的 proto）
    local proto = luac.undump(data, false)
    
    local ok_run, err = pcall(function()
        if mod.strip then mod.strip(proto)
        elseif mod.obfuscate then mod.obfuscate(proto)
        elseif mod.process then mod.process(proto)
        else error('no entry function') end
    end)
    
    if not ok_run then
        print(string.format('%-20s RUN_FAIL: %s', name, tostring(err):sub(1, 80)))
        goto continue
    end
    
    local out = luac.dump(proto)
    local func, lerr = load(out)
    local load_ok = func and 'OK' or ('FAIL: '..tostring(lerr):sub(1, 60))
    print(string.format('%-20s size=%-8d load=%s', name, #out, load_ok))
    
    ::continue::
end
print('done')
