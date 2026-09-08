local luac = require("luac")
local all = {"const_hide_c","const_shuffle_c","str_encrypt_c","instruction_mutate_c","num_obfuscate_c","str_split_c","bool_obfuscate_c","table_obfuscate_c","opaque_predicate_c","const_poison_c","opaque_junk_c","junk_jmp_c","junk_loadk_c","junk_move_c","luac_obfuscate_c","luac_flatten_c","debug_strip_c","antidec_c","proto_shuffle_c","live_range_split_c","op48_junk_c"}
local code = [[print(6) print("6") print(true)]]
local function test(mods, label)
    luac.srand(1)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for _, m in ipairs(mods) do luac[m](p) end
    local bc = luac.dump(p, true)
    local f = load(bc)
    if not f then print(label.." LOAD FAIL"); return end
    local old = print; local out = {}
    print = function(...) out[#out+1]=tostring(...) end
    local ok, e = pcall(f)
    print = old
    if not ok then print(label.." EXEC FAIL: "..tostring(e)) else print(label.." OK: "..table.concat(out,"|")) end
end
-- without const_hide
local m1 = {}
for _,m in ipairs(all) do if m ~= "const_hide_c" then m1[#m1+1]=m end end
test(m1, "no ch")
-- without str_encrypt
local m2 = {}
for _,m in ipairs(all) do if m ~= "str_encrypt_c" then m2[#m2+1]=m end end
test(m2, "no se")
-- only first 5
test({"const_hide_c","const_shuffle_c","str_encrypt_c","instruction_mutate_c","num_obfuscate_c"}, "first5")
print("DONE")
