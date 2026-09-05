local luac = require("luac")

local f = io.open("E:/LuaRes/layout_clean.lua", "rb")
local data = f:read("*a")
f:close()

local p = luac.undump(data, false)

local op_counts = {}
local total_insts = 0

local function count_func(proto)
    for i = 1, #proto.code do
        local op = proto.code[i] % 64
        op_counts[op] = (op_counts[op] or 0) + 1
        total_insts = total_insts + 1
    end
    for i = 1, #proto.p do
        count_func(proto.p[i])
    end
end

count_func(p)

print("Total instructions after cleanup: " .. total_insts)
print("\nOpcode distribution:")
local names = {
    [0]="MOVE",[1]="LOADK",[2]="LOADKX",[3]="LOADBOOL",[4]="LOADNIL",
    [5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[8]="SETTABUP",
    [9]="SETTABLE",[10]="NEWTABLE",[11]="SELF",[12]="ADD",[13]="SUB",
    [14]="MUL",[15]="MOD",[16]="POW",[17]="DIV",[18]="IDIV",
    [19]="BAND",[20]="BOR",[21]="BXOR",[22]="SHL",[23]="SHR",
    [24]="UNM",[25]="BNOT",[26]="NOT",[27]="LEN",[28]="CONCAT",
    [29]="JMP",[30]="EQ",[31]="LT",[32]="LE",[33]="TEST",
    [34]="TESTSET",[35]="CALL",[36]="TAILCALL",[37]="RETURN",
    [38]="FORLOOP",[39]="FORPREP",[40]="TFORCALL",[41]="TFORLOOP",
    [42]="SETLIST",[43]="CLOSURE",[44]="VARARG",[45]="EXTRAARG",
}

local sorted = {}
for op, count in pairs(op_counts) do
    table.insert(sorted, {op=op, count=count})
end
table.sort(sorted, function(a, b) return a.count > b.count end)

for _, item in ipairs(sorted) do
    local name = names[item.op] or ("OP_" .. item.op)
    local pct = string.format("%.1f%%", item.count / total_insts * 100)
    print(string.format("  %-12s %8d  %s", name, item.count, pct))
end

-- 分析 main 函数的前 100 条指令模式
print("\nMain function first 80 instructions:")
for i = 1, math.min(80, #p.code) do
    local inst = p.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local b = (inst >> 23) & 0x1FF
    local c = (inst >> 14) & 0x1FF
    local name = names[op] or ("OP_" .. op)
    print(string.format("  [%3d] 0x%08X %-10s A=%d B=%d C=%d", i, inst, name, a, b, c))
end
