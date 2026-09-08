local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.instruction_mutate_c(p); luac.num_obfuscate_c(p); luac.str_split_c(p); luac.bool_obfuscate_c(p); luac.table_obfuscate_c(p); luac.opaque_predicate_c(p)
-- dump FORPREP/FORLOOP/JMP before obf
local c = p.code
for i = 0, #c-1 do
    local op = c[i] % 64
    if op == 30 or op == 39 or op == 40 or op == 42 then
        local a = math.floor(c[i] / 64) % 256
        local sbx = math.floor(c[i] / 16384) - 131071
        local tgt = i + sbx + 1
        local opname = op==30 and "JMP" or op==39 and "FORLOOP" or op==40 and "FORPREP" or "TFORLOOP"
        print(string.format("before obf [%d] %s a=%d sbx=%d target=%d (n=%d)", i, opname, a, sbx, tgt, #c))
    end
end
print("---")
luac.luac_obfuscate_c(p)
local c2 = p.code
for i = 0, #c2-1 do
    local op = c2[i] % 64
    if op == 30 or op == 39 or op == 40 or op == 42 then
        local sbx = math.floor(c2[i] / 16384) - 131071
        local tgt = i + sbx + 1
        if tgt < 0 or tgt >= #c2 then
            local opname = op==30 and "JMP" or op==39 and "FORLOOP" or op==40 and "FORPREP" or "TFORLOOP"
            print(string.format("after obf BAD [%d] %s sbx=%d target=%d (n=%d)", i, opname, sbx, tgt, #c2))
        end
    end
end
print("DONE")
