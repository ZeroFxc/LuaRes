local luac = require("luac")

local OP_NAMES = {
    [0]="MOVE",[1]="LOADK",[2]="LOADKX",[3]="LOADBOOL",[4]="LOADNIL",
    [5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[8]="SETTABUP",
    [9]="SETUPVAL",[10]="SETTABLE",[11]="NEWTABLE",[12]="SELF",
    [13]="ADD",[14]="SUB",[15]="MUL",[16]="MOD",[17]="POW",
    [18]="DIV",[19]="IDIV",[20]="BAND",[21]="BOR",[22]="BXOR",
    [23]="SHL",[24]="SHR",[25]="UNM",[26]="BNOT",[27]="NOT",
    [28]="LEN",[29]="CONCAT",[30]="JMP",[31]="EQ",[32]="LT",
    [33]="LE",[34]="TEST",[35]="TESTSET",[36]="CALL",[37]="TAILCALL",
    [38]="RETURN",[39]="FORLOOP",[40]="FORPREP",[41]="TFORCALL",
    [42]="TFORLOOP",[43]="SETLIST",[44]="CLOSURE",[45]="VARARG",
    [46]="EXTRAARG"
}

local function disasm(proto, indent)
    indent = indent or ""
    print(string.format("%s=== Proto: sizecode=%d sizek=%d sizep=%d maxstack=%d ===",
        indent, proto.sizecode, proto.sizek, proto.sizep, proto.maxstacksize))
    for i = 0, proto.sizecode - 1 do
        local ins = proto.code[i]
        local op = ins % 64
        local a = math.floor(ins / 64) % 256
        local c = math.floor(ins / 16384) % 512
        local b = math.floor(ins / 8388608) % 512
        local bx = math.floor(ins / 16384)
        local sbx = bx - 131071
        local name = OP_NAMES[op] or ("OP" .. op)
        local desc
        if op == 1 or op == 2 or op == 44 then -- LOADK, LOADKX, CLOSURE
            desc = string.format("A=%d Bx=%d", a, bx)
        elseif op == 30 or op == 39 or op == 40 or op == 42 then -- JMP, FORLOOP, FORPREP, TFORLOOP
            desc = string.format("A=%d sBx=%d (target=%d)", a, sbx, i + sbx + 1)
        elseif op == 36 or op == 37 or op == 38 or op == 43 or op == 45 then -- CALL, TAILCALL, RETURN, SETLIST, VARARG
            desc = string.format("A=%d B=%d C=%d", a, b, c)
        else
            desc = string.format("A=%d B=%d C=%d", a, b, c)
        end
        print(string.format("%s  [%4d] %s %s", indent, i, name, desc))
    end
    for i = 0, proto.sizep - 1 do
        disasm(proto.p[i], indent .. "  ")
    end
end

local f = loadfile("smoke_target.lua")
local bc = string.dec(string.dump(f, true))

-- Test with num+const_hide+str_encrypt
local p = luac.undump(bc, false)
luac.num_obfuscate_c(p)
luac.const_hide_c(p)
luac.str_encrypt_c(p)

print("========== num+const_hide+str_encrypt ==========")
-- only dump main function (first proto is the chunk, its first sub-proto is main?)
-- Actually the top-level proto IS the main chunk
disasm(p, "")
