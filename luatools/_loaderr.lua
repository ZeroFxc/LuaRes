local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.luac_obfuscate_c(p)
local bc = luac.dump(p, true)
io.write("dump len="..#bc.."\n"); io.flush()
local f, err = load(bc)
io.write("load: f="..tostring(f).." err="..tostring(err).."\n"); io.flush()
if f then f() end
