local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
local mods = {"const_hide_c","const_shuffle_c","str_encrypt_c","instruction_mutate_c","num_obfuscate_c","str_split_c","bool_obfuscate_c","table_obfuscate_c","opaque_predicate_c","luac_obfuscate_c"}
for _, m in ipairs(mods) do
    luac[m](p)
    io.write(m..": sizecode="..tostring(p.sizecode).." maxstack="..tostring(p.maxstacksize).." sizek="..tostring(p.sizek).."\n"); io.flush()
end
print("DONE")
