local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
local m456 = {"instruction_mutate_c","num_obfuscate_c","str_split_c"}
local m789 = {"bool_obfuscate_c","table_obfuscate_c","opaque_predicate_c"}
for _, a in ipairs(m456) do
    for _, b in ipairs(m789) do
        luac.srand(1)
        local p = luac.undump(string.dec(string.dump(load(code), true)), false)
        luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
        luac[a](p); luac[b](p)
        luac.luac_obfuscate_c(p)
        local bc = luac.dump(p, true)
        local f = load(bc)
        if not f then print(a.."+"..b.." LOAD FAIL")
        else
            local ok, e = pcall(f)
            if not ok then print(a.."+"..b.." CRASH: "..tostring(e))
            else print(a.."+"..b.." OK") end
        end
    end
end
print("DONE")
