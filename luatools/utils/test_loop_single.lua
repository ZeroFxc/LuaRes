package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')

local FORWARD_ORDER = {
    'bool_obfuscate', 'num_obfuscate', 'str_split', 'const_hide', 'str_encrypt',
    'const_shuffle',
}
local FORWARD_FN = {
    bool_obfuscate='obfuscate', num_obfuscate='obfuscate', str_split='obfuscate',
    const_hide='process', str_encrypt='encrypt', const_shuffle='shuffle',
}

local src = io.open('utils/ad_test.lua', 'rb'):read('*a')
local bc = string.dec(string.dump(load(src)))
local mods = {}
for _, name in ipairs(FORWARD_ORDER) do mods[name] = require(name) end

for trial = 1, 200 do
    local p = luac.undump(bc, false)
    for _, name in ipairs(FORWARD_ORDER) do
        local fn = mods[name][FORWARD_FN[name]]
        pcall(fn, p, {})
    end
    local enc = luac.dump(p)
    local f, lerr = load(enc)
    if not f then
        print(string.format("trial %d: LOAD FAILED: %s", trial, tostring(lerr)))
        os.exit(1)
    end
    local old_print = print
    print = function() end
    local ok, r = pcall(f)
    print = old_print
    if not ok then
        print(string.format("trial %d: RUN FAILED: %s", trial, tostring(r):sub(1,200)))
        -- dump const pool for debugging
        print("=== main proto k after shuffle ===")
        for i = 1, math.min(p.sizek, 50) do
            print(string.format("  k[%d] = %s", i-1, tostring(p.k[i]):sub(1,40)))
        end
        os.exit(1)
    end
    if trial % 20 == 0 then print(string.format("trial %d: ok", trial)) end
end
print("all 200 trials ok")
