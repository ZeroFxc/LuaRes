local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
io.write("before obf: sizecode="..p.sizecode.." sizek="..p.sizek.."\n")
luac.luac_obfuscate_c(p)
io.write("after obf: sizecode="..p.sizecode.." sizek="..p.sizek.."\n")
local bc = luac.dump(p, true)
io.write("bytecode length: "..#bc.."\n")
-- parse sizek from bytecode manually
-- header is 12 bytes (lua 5.3), then function: source, linedefined, lastlinedefined, numparams, is_vararg, maxstack, sizecode, ...
-- this is complex, just load and check
local f = load(bc)
io.write("load ok\n")
-- can't easily check proto sizek from loaded function
f()
io.write("exec ok\n")
