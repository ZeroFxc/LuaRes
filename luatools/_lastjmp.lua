local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.luac_obfuscate_c(p)
local c = p.code
local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}
for i = 1, #c do
    local op = c[i] % 64
    if op == 30 or op == 39 or op == 40 or op == 42 then
        local sbx = math.floor(c[i] / 16384) - 131071
        local tgt = i - 1 + sbx + 1
        if tgt >= #c - 3 then
            local pos_in_group = (i-1) % 3
            print(string.format("[%d] pos%d %s sbx=%d -> [%d] (last group area, n=%d)", i-1, pos_in_group, opnames[op+1], sbx, tgt, #c))
        end
    end
end
-- also check what's at the end
print("--- last 6 instructions ---")
for i = #c-5, #c do
    local op = c[i] % 64
    print(string.format("[%d] %s", i-1, opnames[op+1]))
end
