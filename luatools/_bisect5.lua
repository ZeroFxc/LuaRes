print("START")
local luac = require("luac")
print("REQUIRED")
local all = {"const_hide_c","const_shuffle_c","str_encrypt_c","instruction_mutate_c","num_obfuscate_c","str_split_c","bool_obfuscate_c","table_obfuscate_c","opaque_predicate_c","const_poison_c","opaque_junk_c","junk_jmp_c","junk_loadk_c","junk_move_c","luac_obfuscate_c"}
local code = [[print(6) print("6") print(true)]]
print("CODE LOADED")
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
print("UNDUMP DONE")
for i = 1, 14 do
    print("running "..all[i])
    luac[all[i]](p)
end
print("running luac_obfuscate_c")
luac.luac_obfuscate_c(p)
print("OBF DONE")
local bc = luac.dump(p, true)
print("DUMP DONE")
local f = load(bc)
print("LOAD DONE")
f()
print("DONE")
