local luac = require('luac')

local src = 'local a="hello" local b=42 local t={x=1} if a=="hello" then return b else return 0 end'
local func = load(src)
local bc = string.dec(string.dump(func))

local modules = {
    "str_encrypt_c", "const_hide_c", "const_shuffle_c",
    "debug_strip_c", "bool_obfuscate_c", "num_obfuscate_c",
}

for _, mod in ipairs(modules) do
    local proto = luac.undump(bc, false)
    local ok, n = pcall(function() return luac[mod](proto) end)
    if not ok then
        print(string.format("FAIL %-20s error: %s", mod, tostring(n)))
    else
        local enc = luac.dump(proto)
        local rok, result = pcall(load(enc))
        if rok and result == 42 then
            print(string.format("PASS %-20s changes=%s result=%s", mod, tostring(n), tostring(result)))
        else
            print(string.format("FAIL %-20s changes=%s result=%s err=%s", mod, tostring(n), tostring(result), tostring(rok)))
        end
    end
end

-- combined test
local proto = luac.undump(bc, false)
luac.str_encrypt_c(proto)
luac.const_shuffle_c(proto)
luac.bool_obfuscate_c(proto)
luac.num_obfuscate_c(proto)
luac.debug_strip_c(proto)
local enc = luac.dump(proto)
local ok, result = pcall(load(enc))
print(string.format("PASS combined           result=%s", tostring(result)))
