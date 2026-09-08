local luac = require("luac")
local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}

local function disasm(name, src)
    local bc = string.dec(string.dump(load(src), true))
    local p = luac.undump(bc, false)
    print("=== " .. name .. " (sizecode=" .. p.sizecode .. ") ===")
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
        elseif op >= 31 and op <= 35 then
            extra = " (cond, next is JMP)"
        end
        print(string.format("  [%03d] %-10s A=%d B=%d C=%d%s", i-1, opnames[op+1], a, b, c, extra))
    end
end

disasm("if-elseif-else", [[
local x = 5
if x > 10 then
    print("big")
elseif x > 5 then
    print("medium")
else
    print("small")
end
]])

disasm("while-loop", [[
local i = 0
while i < 3 do
    print(i)
    i = i + 1
end
]])

disasm("for-loop", [[
for i = 1, 3 do
    print(i)
end
]])

disasm("repeat-until", [[
local i = 0
repeat
    print(i)
    i = i + 1
until i >= 3
]])

disasm("nested-if", [[
local a, b = 1, 2
if a > 0 then
    if b > 0 then
        print("both")
    else
        print("only a")
    end
else
    print("none")
end
]])

disasm("and-or", [[
local x = true
local y = false
local z = x and y or true
print(z)
]])
