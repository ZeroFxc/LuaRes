local src = io.open("_vmout.lua", "r"):read("*a")
-- find code={...}
local cstart = src:find("code={", 1, true)
local cend = src:find("},", cstart, true)
local cstr = src:sub(cstart+6, cend-1)
-- parse instructions: {op,a,bop,c,bx,sbx}
local nil_consts = {[0]=true,[1]=true,[2]=true,[5]=true,[6]=true,[7]=true,[8]=true}
local idx = 0
for ins in cstr:gmatch("{(%d+),(%d+),(%d+),(%d+),(%d+),(-?%d+)}") do
    local op, a, b, c, bx, sbx = tonumber(ins:match("^{(%d+)")), tonumber(ins:match(",(%d+),")), 0, 0, 0, 0
    -- parse properly
    local op2, a2, b2, c2 = ins:match("^{(%%d+),(%%d+),(%%d+),(%%d+)")
    idx = idx + 1
end
-- simpler: just gmatch all fields
local idx2 = 0
for op, a, b, c, bx, sbx in cstr:gmatch("{(%d+),(%d+),(%d+),(%d+),(%d+),(-?%d+)}") do
    op, a, b, c = tonumber(op), tonumber(a), tonumber(b), tonumber(c)
    local bk = b >= 256 and (b - 256) or nil
    local ck = c >= 256 and (c - 256) or nil
    if (bk and nil_consts[bk]) or (ck and nil_consts[ck]) then
        local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}
        print(string.format("  ins[%d] %s a=%d b=%d(%s) c=%d(%s)", idx2, opnames[op+1] or op, a, b, bk and ("k["..bk.."]=nil") or "reg", c, ck and ("k["..ck.."]=nil") or "reg"))
    end
    idx2 = idx2 + 1
end
print("total instructions: "..idx2)
