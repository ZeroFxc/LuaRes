package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')

local FORWARD_ORDER = {
    'bool_obfuscate', 'num_obfuscate', 'str_split', 'const_hide', 'str_encrypt',
    'const_shuffle', 'instruction_mutate', 'table_obfuscate', 'opaque_predicate',
    'const_poison', 'opaque_junk', 'junk_jmp',
}
local FORWARD_FN = {
    bool_obfuscate='obfuscate', num_obfuscate='obfuscate', str_split='obfuscate',
    const_hide='process', str_encrypt='encrypt', const_shuffle='shuffle',
    instruction_mutate='process_function', table_obfuscate='obfuscate',
    opaque_predicate='process_function', const_poison='poison',
    opaque_junk='inject', junk_jmp='inject',
}

local src = io.open('utils/ad_test.lua', 'rb'):read('*a')
local bc = string.dec(string.dump(load(src)))
local mods = {}
for _, name in ipairs(FORWARD_ORDER) do mods[name] = require(name) end

local function test_run(p)
    local enc = luac.dump(p)
    local f, lerr = load(enc)
    if not f then return false, "LOAD: "..tostring(lerr) end
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
            print(string.format("trial %d: BROKEN after %s -> %s", trial, name, err))
            break
        end
    end
    if not broken then
        print(string.format("trial %d: all ok (code=%d)", trial, #p.code))
    end
end
print("done")
