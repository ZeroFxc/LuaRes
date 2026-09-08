local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.luac_obfuscate_c(p)
local bc1 = luac.dump(p, true)
io.write("bc1 len="..#bc1.."\n"); io.flush()
local f = load(bc1)
io.write("load ok\n"); io.flush()
-- re-dump with standard string.dump
local bc2 = string.dump(f, true)
io.write("bc2 len="..#bc2.."\n"); io.flush()
-- compare
if bc1 == bc2 then
    io.write("MATCH\n"); io.flush()
else
    io.write("MISMATCH\n"); io.flush()
    -- find first diff
    for i=1,math.min(#bc1,#bc2) do
        if bc1:byte(i) ~= bc2:byte(i) then
            io.write(string.format("first diff at %d: %02x vs %02x\n", i, bc1:byte(i), bc2:byte(i))); io.flush()
            break
        end
    end
end
