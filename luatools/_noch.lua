local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
-- NO const_hide, NO const_shuffle
luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.luac_obfuscate_c(p)
local bc = luac.dump(p, true)
local f = load(bc)
io.write("load ok\n"); io.flush()
f()
io.write("exec ok\n"); io.flush()
