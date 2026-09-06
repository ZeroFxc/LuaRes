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
    bool_obfuscate = 'obfuscate', num_obfuscate = 'obfuscate', str_split = 'obfuscate',
    str_encrypt = 'encrypt', const_hide = 'process', const_shuffle = 'shuffle',
    instruction_mutate = 'process_function', table_obfuscate = 'obfuscate',
    opaque_predicate = 'process_function', const_poison = 'poison',
    opaque_junk = 'inject', junk_jmp = 'inject', junk_loadk = 'inject',
    junk_move = 'inject', op48_junk = 'inject',
    luac_obfuscate = 'obfuscate_proto', luac_flatten = 'flatten_proto',
    debug_strip = 'strip', antidec = 'protect',
}

local src = io.open('utils/ad_test.lua', 'rb'):read('*a')
local bc = string.dec(string.dump(load(src)))

local mods = {}
for _, name in ipairs(FORWARD_ORDER) do
    mods[name] = require(name)
end

local p = luac.undump(bc, false)
for _, name in ipairs(FORWARD_ORDER) do
    local fn = mods[name][FORWARD_FN[name]]
    local ok, err = pcall(fn, p, {})
    if not ok then print(name, 'CRASH:', err) end
end
fix_maxstack.fix(p)

local enc = luac.dump(p)
print('dump size:', #enc)
local f, lerr = load(enc)
print('load:', f ~= nil, lerr)
if f then
    local ok, r = pcall(f)
    print('run:', ok, r)
end
