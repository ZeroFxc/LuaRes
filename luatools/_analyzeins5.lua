local src = io.open("_vmout.lua", "r"):read("*a")
-- code={...}, k={...}
local cstart = src:find("code={", 1, true) + 5  -- after "code="
local kend = src:find("k={", cstart, true)
-- code array is from cstart to kend-2 (before ",\n  k=")
local cstr = src:sub(cstart, kend-3)
-- remove outer braces
cstr = cstr:sub(2, -2)
local nil_consts = {[0]=true,[1]=true,[2]=true,[5]=true,[6]=true,[7]=true,[8]=true}
local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}
local idx = 0
for chunk in string.gmatch(cstr, "{([^}]+)}") do
    local fields = {}
    for f in string.gmatch(chunk, "%-?%d+") do fields[#fields+1] = tonumber(f) end
    local op, a, b, c = fields[1], fields[2], fields[3], fields[4]
    if op then
        local bk = b >= 256 and (b - 256) or nil
        local ck = c >= 256 and (c - 256) or nil
        if (bk and nil_consts[bk]) or (ck and nil_consts[ck]) then
            print(string.format("  ins[%d] %s a=%d b=%d(%s) c=%d(%s)", idx, opnames[op+1] or tostring(op), a, b, bk and ("k["..bk.."]=nil") or "reg", c, ck and ("k["..ck.."]=nil") or "reg"))
        end
        idx = idx + 1
    end
end
print("total instructions: "..idx)
