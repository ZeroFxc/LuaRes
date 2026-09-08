local luac = require("luac")
local all = {"const_hide_c","const_shuffle_c","str_encrypt_c","instruction_mutate_c","num_obfuscate_c","str_split_c","bool_obfuscate_c","table_obfuscate_c","opaque_predicate_c","const_poison_c","opaque_junk_c","junk_jmp_c","junk_loadk_c","junk_move_c","luac_obfuscate_c"}
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
for i = 1, 14 do
    io.stderr:write("running "..all[i].."\n")
    luac[all[i]](p)
end
io.stderr:write("running luac_obfuscate_c\n")
luac.luac_obfuscate_c(p)
io.stderr:write("dump\n")
local bc = luac.dump(p, true)
io.stderr:write("load\n")
local f = load(bc)
io.stderr:write("exec\n")
f()
io.stderr:write("DONE\n")
