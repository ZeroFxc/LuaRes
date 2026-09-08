local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
local function test(mods, label)
    luac.srand(1)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
    for _, m in ipairs(mods) do luac[m](p) end
    luac.luac_obfuscate_c(p)
    local bc = luac.dump(p, true)
    local f = load(bc)
    if not f then print(label.." LOAD FAIL"); return end
    local ok, e = pcall(f)
    if not ok then print(label.." CRASH/FAIL: "..tostring(e)) else print(label.." OK") end
end
test({"instruction_mutate_c","num_obfuscate_c","str_split_c"}, "4-6")
test({"bool_obfuscate_c","table_obfuscate_c","opaque_predicate_c"}, "7-9")
print("DONE")
