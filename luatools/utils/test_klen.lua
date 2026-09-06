package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')

local FORWARD_ORDER = {
    'bool_obfuscate', 'num_obfuscate', 'str_split', 'const_hide', 'str_encrypt',
}
local FORWARD_FN = {
    bool_obfuscate='obfuscate', num_obfuscate='obfuscate', str_split='obfuscate',
    const_hide='process', str_encrypt='encrypt',
}

local src = io.open('utils/ad_test.lua', 'rb'):read('*a')
local bc = string.dec(string.dump(load(src)))
local mods = {}
for _, name in ipairs(FORWARD_ORDER) do mods[name] = require(name) end

local p = luac.undump(bc, false)
for _, name in ipairs(FORWARD_ORDER) do
    local fn = mods[name][FORWARD_FN[name]]
    pcall(fn, p, {})
    -- check k table
    local klen = #p.k
    local actual_max = 0
    local holes = 0
    for i = 1, p.sizek do
        if p.k[i] ~= nil then actual_max = i else holes = holes + 1 end
    end
    print(string.format("%-18s sizek=%d #k=%d actual_max=%d holes=%d", name, p.sizek, klen, actual_max, holes))
end
