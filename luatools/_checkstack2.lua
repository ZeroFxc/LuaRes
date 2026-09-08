local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.luac_obfuscate_c(p)
io.write("maxstack="..p.maxstacksize.." sizecode="..p.sizecode.."\n"); io.flush()
local maxa = 0
for i=0,p.sizecode-1 do
    local a = (p.code[i] >> 6) & 0xFF
    if a > maxa then maxa = a end
end
io.write("max A register: "..maxa.."\n"); io.flush()
if maxa >= p.maxstacksize then
    io.write("OVERFLOW: A="..maxa.." >= maxstack="..p.maxstacksize.."\n"); io.flush()
else
    io.write("stack OK\n"); io.flush()
end
