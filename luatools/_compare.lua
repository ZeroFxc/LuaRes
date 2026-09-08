local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.luac_obfuscate_c(p)
io.write("before dump: sizek="..p.sizek.."\n"); io.flush()
local before = {}
for i=80,95 do before[i] = tostring(p.k[i]) end
local bc = luac.dump(p, true)
io.write("dumped "..#bc.." bytes\n"); io.flush()
local p2 = luac.undump(bc, false)
io.write("after undump: sizek="..p2.sizek.."\n"); io.flush()
for i=80,95 do
    local match = before[i] == tostring(p2.k[i]) and "OK" or "DIFF"
    io.write(string.format("  k[%d] %s: %s vs %s\n", i, match, before[i], tostring(p2.k[i]))); io.flush()
end
