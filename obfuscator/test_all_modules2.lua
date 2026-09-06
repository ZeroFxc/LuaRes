package.path = package.path .. ';E:/LuaRes/luatools/forward/?.lua'
local luac = require('luac')

local modules = {
    {'bool_obfuscate', 'strip'},
    {'num_obfuscate', 'strip'},
    {'str_split', 'strip'},
    {'str_encrypt', 'encrypt'},
    {'const_shuffle', 'shuffle'},
    {'instruction_mutate', 'process_function'},
    {'opaque_predicate', 'strip'},
    {'const_poison', 'poison'},
    {'opaque_junk', 'inject'},
    {'junk_jmp', 'inject'},
    {'junk_loadk', 'inject'},
    {'junk_move', 'inject'},
    {'op48_junk', 'inject'},
    {'luac_obfuscate', 'obfuscate_proto'},
    {'luac_flatten', 'flatten_proto'},
    {'debug_strip', 'strip'},
    {'antidec', 'protect'},
}

local f = io.open('E:/LuaRes/tk.lua', 'rb')
local data = f:read('*a')
f:close()
print('input size:', #data)

for _, entry in ipairs(modules) do
    local name, func_name = entry[1], entry[2]
    local ok_mod, mod = pcall(require, name)
    if not ok_mod then
        print(string.format('%-20s LOAD_FAIL: %s', name, tostring(mod):sub(1,60)))
        goto continue
    end
    
    local fn = mod[func_name]
    if not fn then
        print(string.format('%-20s NO_FUNC: %s', name, func_name))
        goto continue
    end
    
    local proto = luac.undump(data, false)
    
    local ok_run, err = pcall(fn, proto)
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
