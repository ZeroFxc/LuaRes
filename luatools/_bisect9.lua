local luac = require("luac")
local f = loadfile("smoke_target.lua")
local bc = string.dec(string.dump(f, true))

local function test(modules, label)
    local p = luac.undump(bc, false)
    for _, name in ipairs(modules) do
        local fn = luac[name .. '_c']
        if fn then pcall(fn, p) end
    end
    local d = luac.dump(p)
    local r = load(d)
    if r then
        local ok, err = pcall(r)
        print(label .. ": " .. (ok and "OK" or ("FAIL: " .. tostring(err):sub(1,60))))
    else
        print(label .. ": LOAD_FAIL")
    end
end

local base6 = {'const_hide','const_shuffle','str_encrypt','num_obfuscate','str_split','bool_obfuscate'}
local rest = {'instruction_mutate','table_obfuscate','opaque_predicate',
    'const_poison','opaque_junk','junk_jmp','junk_loadk','junk_move','op48_junk',
    'luac_obfuscate','luac_flatten','debug_strip','antidec','proto_shuffle','live_range_split'}

-- test base6 + each rest module individually
for _, name in ipairs(rest) do
    local m = {}
    for _, v in ipairs(base6) do table.insert(m, v) end
    table.insert(m, name)
    test(m, "base6+" .. name)
end
