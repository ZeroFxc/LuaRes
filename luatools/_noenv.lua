local luac = require("luac")
local code = [[local x=6; local y="6"; local z=true]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.luac_obfuscate_c(p)
local bc = luac.dump(p, true)
local f = load(bc, nil, "bt", {})  -- empty env
io.write("load ok\n"); io.flush()
f()
io.write("exec ok\n"); io.flush()
