local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.luac_obfuscate_c(p)
io.write("maxstack="..p.maxstacksize.."\n"); io.flush()
p.maxstacksize = 255  -- max possible for 8-bit A field
local bc = luac.dump(p, true)
local f = load(bc)
io.write("load ok\n"); io.flush()
local ok, err = pcall(f)
io.write("pcall: ok="..tostring(ok).." err="..tostring(err).."\n"); io.flush()
