local luac = require("luac")
local all = {"const_hide_c","const_shuffle_c","str_encrypt_c","instruction_mutate_c","num_obfuscate_c","str_split_c","bool_obfuscate_c","table_obfuscate_c","opaque_predicate_c","const_poison_c","opaque_junk_c","junk_jmp_c","junk_loadk_c","junk_move_c","luac_obfuscate_c","luac_flatten_c","debug_strip_c","antidec_c","proto_shuffle_c","live_range_split_c","op48_junk_c"}
local code = [[print(6) print("6") print(true)]]
local function test(n, label)
    luac.srand(1)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for i = 1, n do luac[all[i]](p) end
    local bc = luac.dump(p, true)
    local f = load(bc)
    if not f then print(label.." LOAD FAIL"); return end
    local old = print; local out = {}
    print = function(...) out[#out+1]=tostring(...) end
    local ok, e = pcall(f)
    print = old
    if not ok then print(label.." EXEC FAIL: "..tostring(e)) else print(label.." OK") end
end
for n = 6, 21 do
    test(n, "first"..n.."("..all[n]..")")
end
print("DONE")
