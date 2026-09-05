local luac = require("luac")

local f = io.open("E:/LuaRes/fangtd_standard.lua", "rb")
local data = f:read("*a")
f:close()

print("=== File size: " .. #data .. " ===")

-- 检查 header 前 40 字节
print("\n=== Header (first 40 bytes) ===")
for i = 1, 40 do
    io.write(string.format("%02X ", data:byte(i)))
    if i % 16 == 0 then io.write("\n") end
end
io.write("\n")

-- undump
local p = luac.undump(data, false)
print("\n=== Main function header ===")
print("source len: " .. #(p.source or ""))
print("linedefined: " .. p.linedefined)
print("lastlinedefined: " .. p.lastlinedefined)
print("numparams: " .. p.numparams)
print("is_vararg: " .. p.is_vararg)
print("maxstacksize: " .. p.maxstacksize)
print("sizecode: " .. #p.code)
print("sizek: " .. #p.k)
print("sizep: " .. #p.p)
print("sizeupvalues: " .. p.sizeupvalues)
print("sizelineinfo: " .. #p.lineinfo)
print("sizelocvars: " .. #p.locvars)

-- 检查常量池 tag
print("\n=== Main constants ===")
for i = 1, #p.k do
    local v = p.k[i]
    print(string.format("  [%d] type=%s value=%s", i, type(v), tostring(v):sub(1, 50)))
end

-- 检查前几条指令
print("\n=== Main first 10 instructions ===")
for i = 1, math.min(10, #p.code) do
    local op = p.code[i] % 64
    print(string.format("  [%d] opcode=%d raw=0x%08X", i, op, p.code[i]))
end

-- 递归检查所有函数的异常
print("\n=== Scanning all functions for anomalies ===")
local stats = {
    total = 0,
    bad_numparams = 0,
    bad_vararg = 0,
    bad_maxstack = 0,
    bad_sizeupvalues = 0,
    bad_lineinfo = 0,
    bad_linedefined = 0,
    zero_code = 0,
    huge_code = 0,
    bad_opcode = 0,
}
local OPCODE_NAMES = {
    [0]="MOVE",[1]="LOADK",[2]="LOADKX",[3]="LOADBOOL",[4]="LOADNIL",
    [5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[8]="SETTABUP",[9]="SETUPVAL",
    [10]="SETTABLE",[11]="NEWTABLE",[12]="SELF",[13]="ADD",[14]="SUB",
    [15]="MUL",[16]="MOD",[17]="POW",[18]="DIV",[19]="IDIV",
    [20]="BAND",[21]="BOR",[22]="BXOR",[23]="SHL",[24]="SHR",
    [25]="UNM",[26]="BNOT",[27]="NOT",[28]="LEN",[29]="CONCAT",
    [30]="JMP",[31]="EQ",[32]="LT",[33]="LE",[34]="TEST",
    [35]="TESTSET",[36]="CALL",[37]="TAILCALL",[38]="RETURN",[39]="FORLOOP",
    [40]="FORPREP",[41]="TFORCALL",[42]="TFORLOOP",[43]="SETLIST",[44]="CLOSURE",
    [45]="VARARG",[46]="EXTRAARG",
}
local function scan(pp)
    stats.total = stats.total + 1
    if pp.numparams > 200 then stats.bad_numparams = stats.bad_numparams + 1 end
    if pp.is_vararg > 10 then stats.bad_vararg = stats.bad_vararg + 1 end
    if pp.maxstacksize > 200 then stats.bad_maxstack = stats.bad_maxstack + 1 end
    if pp.sizeupvalues > 100 then stats.bad_sizeupvalues = stats.bad_sizeupvalues + 1 end
    if #pp.lineinfo ~= #pp.code then stats.bad_lineinfo = stats.bad_lineinfo + 1 end
    if pp.linedefined > 1000000 or pp.linedefined < 0 then stats.bad_linedefined = stats.bad_linedefined + 1 end
    if #pp.code == 0 then stats.zero_code = stats.zero_code + 1 end
    if #pp.code > 50000 then stats.huge_code = stats.huge_code + 1 end
    for i = 1, #pp.code do
        local op = pp.code[i] % 64
        if op > 46 then stats.bad_opcode = stats.bad_opcode + 1 end
    end
    for i = 1, #pp.p do scan(pp.p[i]) end
end
scan(p)

for k, v in pairs(stats) do
    if v > 0 then print(string.format("  %s: %d", k, v)) end
end

-- 检查 sizeupvalues 最大的函数
print("\n=== Top 5 functions by sizeupvalues ===")
local list = {}
local function collect(pp, path)
    table.insert(list, {path=path, sizeupvalues=pp.sizeupvalues, sizecode=#pp.code})
    for i = 1, #pp.p do collect(pp.p[i], path .. "/" .. i) end
end
collect(p, "main")
table.sort(list, function(a, b) return a.sizeupvalues > b.sizeupvalues end)
for i = 1, math.min(5, #list) do
    print(string.format("  %s: sizeupvalues=%d sizecode=%d", list[i].path, list[i].sizeupvalues, list[i].sizecode))
end
