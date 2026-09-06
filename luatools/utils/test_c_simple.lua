local luac = require('luac')
local src = 'local a=42 local b=10 if a>b then return a else return b end'
local bc = string.dec(string.dump(load(src)))

for _, mod in ipairs({"debug_strip_c", "bool_obfuscate_c", "num_obfuscate_c"}) do
    local proto = luac.undump(bc, false)
    local ok, n = pcall(function() return luac[mod](proto) end)
    if not ok then
        print(string.format("CRASH %-20s %s", mod, tostring(n)))
    else
        local enc = luac.dump(proto)
        local rok, result = pcall(load(enc))
        print(string.format("%-20s changes=%s result=%s ok=%s", mod, tostring(n), tostring(result), tostring(rok)))
    end
end
