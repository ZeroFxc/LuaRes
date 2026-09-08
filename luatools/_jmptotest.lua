local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
local c = p.code
local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}
local logical_targets = 0
for i = 1, #c do
    local op = c[i] % 64
    if op == 30 or op == 39 or op == 40 or op == 42 then
        local sbx = math.floor(c[i] / 16384) - 131071
        local tgt = i - 1 + sbx + 1
        if tgt >= 0 and tgt < #c then
            local top = c[tgt+1] % 64
            if top == 31 or top == 32 or top == 33 or top == 34 or top == 35 then
                logical_targets = logical_targets + 1
                if logical_targets <= 10 then
                    print(string.format("[%d] %s -> [%d] %s", i-1, opnames[op+1], tgt, opnames[top+1]))
                end
            end
        end
    end
end
print("JMPs targeting logical ops: "..logical_targets)
