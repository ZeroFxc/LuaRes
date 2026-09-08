local luac = require("luac")
local target = [[local s='hello' local s2=s..' world' local a=string.upper(s) local b=string.sub(s2,1,5) local c=string.format('x=%d y=%s',42,'ok') print(#s2+#a+#b+#c)]]
local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}

luac.srand(1) -- failing seed without flatten
local func = load(target)
local bc = string.dec(string.dump(func, true))
local p = luac.undump(bc, false)
luac.str_encrypt_c(p)
luac.num_obfuscate_c(p)
luac.opaque_predicate_c(p)

print("=== MAIN size="..p.sizecode.." maxstack="..p.maxstacksize.." ===")
local c = p.code
for i = 1, p.sizecode do
    local ins = c[i]
    local op = ins & 0x3F
    local a = (ins >> 6) & 0xFF
    local b = (ins >> 23) & 0x1FF
    local c2 = (ins >> 14) & 0x1FF
    local bx = (ins >> 14) & 0x3FFFF
    local sbx = bx - 131071
    local nm = opnames[op+1] or "OP"..op
    local idx = i - 1
    if op == 1 or op == 2 then
        print(string.format("%4d: %s A=%d Bx=%d", idx, nm, a, bx))
    elseif op == 30 then
        print(string.format("%4d: %s sbx=%d -> %d", idx, nm, sbx, idx + sbx + 1))
    elseif op == 31 or op == 32 or op == 33 then
        print(string.format("%4d: %s A=%d B=%d C=%d", idx, nm, a, b, c2))
    elseif op == 36 or op == 37 or op == 38 then
        print(string.format("%4d: %s A=%d B=%d C=%d", idx, nm, a, b, c2))
    else
        print(string.format("%4d: %s A=%d B=%d C=%d", idx, nm, a, b, c2))
    end
end
print("=== constants ===")
for i = 1, p.sizek do
    local tag = p.k_tag[i-1]
    local val = p.k_num[i-1] or p.k_str[i-1] or "?"
    print(string.format("  k[%d] tag=%d val=%s", i-1, tag, tostring(val)))
end
