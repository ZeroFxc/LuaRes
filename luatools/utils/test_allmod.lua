package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua"
local luac = require('luac')

local FORWARD_ORDER = {
    'bool_obfuscate', 'num_obfuscate', 'str_split', 'const_hide', 'str_encrypt',
    'const_shuffle', 'instruction_mutate', 'table_obfuscate', 'opaque_predicate',
    'const_poison', 'opaque_junk', 'junk_jmp', 'junk_loadk',
    'junk_move', 'op48_junk',
    'luac_obfuscate', 'luac_flatten', 'debug_strip',
    'antidec',
}

local FORWARD_FN = {
    bool_obfuscate = 'obfuscate',
    num_obfuscate = 'obfuscate',
    str_split = 'obfuscate',
    str_encrypt = 'encrypt',
    const_hide = 'process',
    const_shuffle = 'shuffle',
    instruction_mutate = 'process_function',
    table_obfuscate = 'obfuscate',
    opaque_predicate = 'process_function',
    const_poison = 'poison',
    opaque_junk = 'inject',
    junk_jmp = 'inject',
    junk_loadk = 'inject',
    junk_move = 'inject',
    op48_junk = 'inject',
    luac_obfuscate = 'obfuscate_proto',
    luac_flatten = 'flatten_proto',
    debug_strip = 'strip',
    antidec = 'protect',
}

local src = io.open('utils/ad_test.lua', 'rb'):read('*a')
local bc = string.dec(string.dump(load(src)))
local expected = load(bc)()
print('expected:', tostring(expected))

-- load all modules
local mods = {}
for _, name in ipairs(FORWARD_ORDER) do
    local ok, m = pcall(require, name)
    if ok then
        mods[name] = m
    else
        print('LOAD MODULE FAIL:', name, m)
    end
end

-- apply one by one, check load after each
local p = luac.undump(bc, false)
local first_fail = nil
for _, name in ipairs(FORWARD_ORDER) do
    local m = mods[name]
    local fn = m and m[FORWARD_FN[name]]
    if fn then
        local ok, err = pcall(fn, p)
        if not ok then
            print(string.format('%-20s CRASH: %s', name, tostring(err):sub(1,80)))
        else
            -- try to load
            local enc = luac.dump(p)
            local f, lerr = load(enc)
            local runok = 'n/a'
            if f then
                local rok, r = pcall(f)
                runok = rok and (r == expected and 'OK' or 'MISMATCH:'..tostring(r)) or 'RUNERR'
            end
            print(string.format('%-20s applied  load=%s  run=%s', name, tostring(f~=nil), runok))
            if not f and not first_fail then
                first_fail = name
                print('  load error:', lerr)
            end
        end
    else
        print(string.format('%-20s NO FN %s', name, FORWARD_FN[name]))
    end
end

print('first load failure:', first_fail or 'none')
