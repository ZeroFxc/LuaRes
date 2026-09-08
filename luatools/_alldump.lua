local luac = require("luac")
local mods = {"const_hide_c","const_shuffle_c","str_encrypt_c","instruction_mutate_c","num_obfuscate_c","str_split_c","bool_obfuscate_c","table_obfuscate_c","opaque_predicate_c","const_poison_c","opaque_junk_c","junk_jmp_c","junk_loadk_c","junk_move_c","luac_obfuscate_c","luac_flatten_c","debug_strip_c","antidec_c","proto_shuffle_c","live_range_split_c","op48_junk_c"}
local code = [[
print(6)
print("6")
print(true)
print(6.6)
print((function (x) return x end)(6))
print(#"6")
]]
local function run_dump(p)
    local bc = luac.dump(p, true)
    local f = load(bc)
    if not f then return nil, "load failed" end
    local old = print; local out = {}
    print = function(...)
        local args = {...}; local parts = {}
        for i = 1, select("#", ...) do parts[i] = type(args[i])=="table" and "table" or tostring(args[i]) end
        out[#out+1] = table.concat(parts, "\t")
    end
    local ok, e = pcall(f)
    print = old
    if not ok then return nil, e end
    return out
end
local base = run_dump(luac.undump(string.dec(string.dump(load(code), true)), false))
print("baseline: "..table.concat(base, "|"))
for seed = 1, 3 do
    luac.srand(seed)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for _, m in ipairs(mods) do luac[m](p) end
    local out, err = run_dump(p)
    if not out then print("ALL seed"..seed.." FAIL: "..tostring(err))
    else print("ALL seed"..seed..": "..table.concat(out, "|")) end
end
print("DONE")
