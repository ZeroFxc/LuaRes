local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.luac_obfuscate_c(p)
io.write("orig: sizecode="..p.sizecode.."\n"); io.flush()
local orig_code = {}
for i=0,p.sizecode-1 do orig_code[i] = p.code[i] end
local bc = luac.dump(p, true)
local p2 = luac.undump(bc, false)
io.write("undump: sizecode="..p2.sizecode.."\n"); io.flush()
local diff = 0
for i=0,math.min(p.sizecode,p2.sizecode)-1 do
    if orig_code[i] ~= p2.code[i] then
        diff = diff + 1
        if diff <= 10 then
            io.write(string.format("  code[%d] diff: %08x vs %08x\n", i, orig_code[i], p2.code[i])); io.flush()
        end
    end
end
io.write("total code diffs: "..diff.."\n"); io.flush()
-- also check last few instructions
for i=p.sizecode-5,p.sizecode-1 do
    io.write(string.format("  orig code[%d]=%08x undump=%08x\n", i, orig_code[i], p2.code[i] or -1)); io.flush()
end
