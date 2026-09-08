local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
local inter = {"instruction_mutate_c","num_obfuscate_c","str_split_c","bool_obfuscate_c","table_obfuscate_c","opaque_predicate_c","const_poison_c","opaque_junk_c","junk_jmp_c","junk_loadk_c","junk_move_c"}
for _, m in ipairs(inter) do
    luac.srand(1)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    luac.const_hide_c(p)
    luac.const_shuffle_c(p)
    luac.str_encrypt_c(p)
    luac[m](p)
    luac.luac_obfuscate_c(p)
    local bc = luac.dump(p, true)
    local f = load(bc)
    if not f then print(m.." LOAD FAIL")
    else
        local ok, e = pcall(f)
        if not ok then print(m.." EXEC FAIL: "..tostring(e))
        else print(m.." OK") end
    end
end
print("DONE")
