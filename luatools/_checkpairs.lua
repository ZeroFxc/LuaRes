local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.instruction_mutate_c(p); luac.num_obfuscate_c(p); luac.str_split_c(p); luac.bool_obfuscate_c(p); luac.table_obfuscate_c(p); luac.opaque_predicate_c(p)
local c = p.code
local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}
local bad = 0
for i = 1, #c do
    local op = c[i] % 64
    if op == 34 or op == 35 then -- TEST or TESTSET
        local nextop = (i < #c) and (c[i+1] % 64) or -1
        if nextop ~= 30 then
            bad = bad + 1
            print(string.format("[%d] %s not followed by JMP (next=%s)", i-1, opnames[op+1], opnames[nextop+1] or "none"))
        end
    end
    if op == 31 or op == 32 or op == 33 then -- EQ/LT/LE
        local nextop = (i < #c) and (c[i+1] % 64) or -1
        if nextop ~= 30 then
            bad = bad + 1
            print(string.format("[%d] %s not followed by JMP (next=%s)", i-1, opnames[op+1], opnames[nextop+1] or "none"))
        end
    end
end
print("bad logical pairs: "..bad)
-- also check JMP targets
local badjmp = 0
for i = 1, #c do
    local op = c[i] % 64
    if op == 30 or op == 39 or op == 40 or op == 42 then
        local sbx = math.floor(c[i] / 16384) - 131071
        local tgt = i - 1 + sbx + 1
        if tgt < 0 or tgt >= #c then
            badjmp = badjmp + 1
            if badjmp <= 5 then
                print(string.format("[%d] %s sbx=%d target=%d out of range [0,%d]", i-1, opnames[op+1], sbx, tgt, #c-1))
            end
        end
    end
end
print("bad jumps: "..badjmp)
