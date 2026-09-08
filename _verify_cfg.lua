local luac = require("luac")
local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}

local function disasm(p, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    print(indent .. "proto sizecode=" .. p.sizecode .. " sizek=" .. p.sizek)
    for i = 1, p.sizecode do
        local ins = p.code[i]
        local op = ins % 64
        local a = math.floor(ins / 64) % 256
        local c = math.floor(ins / 16384) % 512
        local b = math.floor(ins / 8388608) % 512
        local bx = math.floor(ins / 64) % 262144
        local sbx = bx - 131072
        local extra = ""
        if op == 27 or op == 39 or op == 40 or op == 43 then
            extra = " sbx=" .. sbx .. " target=" .. (i-1) + 1 + sbx
        end
        print(string.format("%s  [%03d] %-10s A=%d B=%d C=%d%s", indent, i-1, opnames[op+1], a, b, c, extra))
    end
    if p.p then
        for i = 1, p.sizep do
            disasm(p.p[i], depth + 1)
        end
    end
end

-- Read the cfg_shuffle output
local f = io.open("_cfg_test_out.luac", "rb")
local bc = f:read("*a")
f:close()

print("=== AFTER cfg_shuffle ===")
local p = luac.undump(bc, false)
disasm(p)

-- Also run it to verify output
print("\n=== RUN OUTPUT ===")
local func = load(bc)
func()
