local luac = require("luac")
local opaque_junk = require("opaque_junk")

local func = load("print('hello')")
local bc = string.dec(string.dump(func))

local names = {[0]="MOVE",[1]="LOADK",[2]="LOADKX",[3]="LOADBOOL",[4]="LOADNIL",
    [5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[8]="SETTABUP",[9]="SETUPVAL",
    [10]="SETTABLE",[11]="NEWTABLE",[12]="SELF",[13]="ADD",[14]="SUB",[15]="MUL",
    [16]="MOD",[17]="POW",[18]="DIV",[19]="IDIV",[20]="BAND",[21]="BOR",[22]="BXOR",
    [23]="SHL",[24]="SHR",[25]="UNM",[26]="BNOT",[27]="NOT",[28]="LEN",[29]="CONCAT",
    [30]="JMP",[31]="EQ",[32]="LT",[33]="LE",[34]="TEST",[35]="TESTSET",
    [36]="CALL",[37]="TAILCALL",[38]="RETURN",[39]="FORLOOP",[40]="FORPREP",
    [41]="TFORCALL",[42]="TFORLOOP",[43]="SETLIST",[44]="CLOSURE",[45]="VARARG",[46]="EXTRAARG"}

for trial = 1, 3 do
    local p = luac.undump(bc, false)
    opaque_junk.inject(p, {count = 1, recursive = false})
    local out = luac.dump(p)
    local ok, f = pcall(load, out)
    local exec_ok = false
    local err = ""
    if ok then
        local old_print = print
        print = function() end
        exec_ok, err = pcall(f)
        print = old_print
    end
    print(string.format("=== trial %d: exec=%s ===", trial, tostring(exec_ok)))
    for i = 1, #p.code do
        local inst = p.code[i]
        local op = inst % 64
        local a = (inst >> 6) & 0xFF
        local b = (inst >> 23) & 0x1FF
        local c = (inst >> 14) & 0x1FF
        local bx = inst >> 14
        local sbx = bx - 131071
        local extra = ""
        if op == 30 then extra = string.format(" sbx=%d ->%d", sbx, i+sbx+1) end
        print(string.format("  [%2d] 0x%08X %-8s A=%d B=%d C=%d%s",
            i, inst, names[op] or tostring(op), a, b, c, extra))
    end
    if not exec_ok then
        print("  ERR: " .. tostring(err))
    end
    print()
end
