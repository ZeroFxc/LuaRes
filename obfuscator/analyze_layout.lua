local luac = require("luac")

local f = io.open("E:/LuaRes/layout.lua", "rb")
local data = f:read("*a")
f:close()

print("File size: " .. #data .. " bytes")

local p = luac.undump(data, false)

-- 统计所有函数的指令
local op_counts = {}
local total_insts = 0
local total_funcs = 0
local invalid_ops = 0

local function count_func(proto)
    total_funcs = total_funcs + 1
    for i = 1, #proto.code do
        local op = proto.code[i] % 64
        op_counts[op] = (op_counts[op] or 0) + 1
        total_insts = total_insts + 1
        if op > 46 then
            invalid_ops = invalid_ops + 1
        end
    end
    for i = 1, #proto.p do
        count_func(proto.p[i])
    end
end

count_func(p)

print("Total functions: " .. total_funcs)
print("Total instructions: " .. total_insts)
print("Invalid ops (>46): " .. invalid_ops .. " (" .. string.format("%.1f%%", invalid_ops/total_insts*100) .. ")")

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

-- 检查 main 函数头
print("\nMain function header:")
print("  numparams: " .. p.numparams)
print("  is_vararg: " .. p.is_vararg)
print("  maxstacksize: " .. p.maxstacksize)
print("  sizeupvalues: " .. #p.upvalues)
print("  code count: " .. #p.code)
print("  constants: " .. #p.k)
print("  protos: " .. #p.p)

-- 检查 upvalue 特征
print("\nMain upvalues (first 10):")
for i = 1, math.min(10, #p.upvalues) do
    local uv = p.upvalues[i]
    print(string.format("  uv[%d]: instack=%s idx=%s name=%s",
        i-1, tostring(uv.instack), tostring(uv.idx), tostring(uv.name)))
end
