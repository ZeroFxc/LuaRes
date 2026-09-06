package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local fix_maxstack = require('fix_maxstack')

local FORWARD_ORDER = {
    'bool_obfuscate', 'num_obfuscate', 'str_split', 'const_hide', 'str_encrypt',
    'const_shuffle', 'instruction_mutate', 'table_obfuscate', 'opaque_predicate',
    'const_poison', 'opaque_junk', 'junk_jmp', 'junk_loadk',
    'junk_move', 'op48_junk',
    'luac_obfuscate', 'luac_flatten', 'debug_strip',
    'antidec',
}
local FORWARD_FN = {
    bool_obfuscate='obfuscate', num_obfuscate='obfuscate', str_split='obfuscate',
    str_encrypt='encrypt', const_hide='process', const_shuffle='shuffle',
    instruction_mutate='process_function', table_obfuscate='obfuscate',
    opaque_predicate='process_function', const_poison='poison',
    opaque_junk='inject', junk_jmp='inject', junk_loadk='inject',
    junk_move='inject', op48_junk='inject',
    luac_obfuscate='obfuscate_proto', luac_flatten='flatten_proto',
    debug_strip='strip', antidec='protect',
}

local src = io.open('utils/ad_test.lua', 'rb'):read('*a')
local bc = string.dec(string.dump(load(src)))
local mods = {}
for _, name in ipairs(FORWARD_ORDER) do mods[name] = require(name) end

local fails = 0
for trial = 1, 50 do
    local p = luac.undump(bc, false)
    local lastmod = "?"
    for _, name in ipairs(FORWARD_ORDER) do
        lastmod = name
        local fn = mods[name][FORWARD_FN[name]]
        pcall(fn, p, {})
    end
    fix_maxstack.fix(p)
    local enc = luac.dump(p)
    local f, lerr = load(enc)
    if not f then
        fails = fails + 1
        print(string.format("trial %d LOADFAIL after %s: %s", trial, lastmod, tostring(lerr)))
    else
        local ok, r = pcall(f)
        if not ok then
            fails = fails + 1
            print(string.format("trial %d RUNERR: %s", trial, tostring(r):sub(1,120)))
        end
    end
end
print(string.format("50 trials, %d failures", fails))
