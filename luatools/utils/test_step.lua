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

-- redirect print to suppress test output
local real_print = print
local function test_run(p)
    local enc = luac.dump(p)
    local f, lerr = load(enc)
    if not f then return false, "LOAD: "..tostring(lerr) end
    -- capture output
    local old_print = print
    print = function() end
    local ok, r = pcall(f)
    print = old_print
    if not ok then return false, "RUN: "..tostring(r):sub(1,100) end
    return true, "ok"
end

for trial = 1, 30 do
    local p = luac.undump(bc, false)
    local broken = nil
    for _, name in ipairs(FORWARD_ORDER) do
        local fn = mods[name][FORWARD_FN[name]]
        pcall(fn, p, {})
        local ok, err = test_run(p)
        if not ok then
            broken = name
            real_print(string.format("trial %d: BROKEN after %s -> %s", trial, name, err))
            break
        end
    end
    if not broken then
        fix_maxstack.fix(p)
        local ok, err = test_run(p)
        if not ok then
            real_print(string.format("trial %d: BROKEN after fix_maxstack -> %s", trial, err))
        end
    end
end
real_print("done")
