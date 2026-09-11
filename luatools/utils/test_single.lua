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

local p = luac.undump(bc, false)
for _, name in ipairs(FORWARD_ORDER) do
    local fn = mods[name][FORWARD_FN[name]]
    pcall(fn, p, {})
    print("applied:", name)
end

-- dump and load
local enc = luac.dump(p)
print("dumped, size=", #enc)
local f, lerr = load(enc)
if not f then
    print("LOAD FAILED:", tostring(lerr))
    os.exit(1)
end
print("loaded ok, running...")
local ok, r = pcall(f)
if not ok then
    print("RUN FAILED:", tostring(r))
else
    print("RUN OK")
end
