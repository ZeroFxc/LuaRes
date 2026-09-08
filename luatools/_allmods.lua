local luac = require("luac")
local code = [[
print(6) print("6") print(true)
local t = {a=1, b="hello", c={1,2,3}}
for i=1,3 do print(i, t.a) end
local function f(x) return x*2 end
print(f(5))
if #t.c > 2 then print("big") end
]]
luac.srand(42)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
-- all modules
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.instruction_mutate_c(p); luac.num_obfuscate_c(p); luac.str_split_c(p)
luac.bool_obfuscate_c(p); luac.table_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.const_poison_c(p); luac.opaque_junk_c(p); luac.junk_jmp_c(p)
luac.junk_loadk_c(p); luac.junk_move_c(p); luac.luac_obfuscate_c(p)
luac.luac_flatten_c(p); luac.debug_strip_c(p); luac.antidec_c(p)
luac.proto_shuffle_c(p); luac.live_range_split_c(p); luac.op48_junk_c(p)
local bc = luac.dump(p, true)
io.write("dump len="..#bc.."\n"); io.flush()
local f = load(bc)
io.write("load ok\n"); io.flush()
f()
io.write("exec ok\n"); io.flush()
