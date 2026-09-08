local luac = require("luac")
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
test({"const_hide_c","str_encrypt_c","luac_obfuscate_c"}, "ch+se+obf")
test({"const_hide_c","luac_obfuscate_c"}, "ch+obf")
test({"str_encrypt_c","luac_obfuscate_c"}, "se+obf")
print("DONE")
