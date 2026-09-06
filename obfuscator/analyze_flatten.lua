local luac = require("luac")

local f = io.open("E:/LuaRes/main(1)_clean2.lua", "rb")
local data = f:read("*a")
f:close()

local p = luac.undump(data, false)

-- 找一个中等大小的函数，分析其指令结构
local function find_func(pp, path, target_size)
    if #pp.code >= target_size and #pp.code <= target_size * 3 then
        return pp, path
    end
    for i = 1, #pp.p do
        local r, rp = find_func(pp.p[i], path .. "/" .. i, target_size)
        if r then return r, rp end
    end
    return nil
end

local target, path = find_func(p, "main", 100)
if not target then
    target = p.p[1]
    path = "main/1"
end

print("Analyzing function: " .. path)
print("Code count: " .. #target.code)
print("Constants: " .. #target.k)
print("Sub funcs: " .. #target.p)

-- 打印前 80 条指令
print("\n=== First 80 instructions ===")
local OP_NAMES = {
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

for i = 1, math.min(80, #target.code) do
    local inst = target.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local c = (inst >> 14) & 0x1FF
    local b = (inst >> 23) & 0x1FF
    local bx = inst >> 14
    local sbx = bx - 131071
    local name = OP_NAMES[op] or ("OP"..op)

    local detail = ""
    if op == 30 then  -- JMP
        detail = string.format(" sBx=%d (->%d)", sbx, i + sbx + 1)
    elseif op == 1 then  -- LOADK
        detail = string.format(" Bx=%d", bx)
    elseif op == 8 then  -- SETTABUP
        detail = string.format(" A=%d B=%d C=%d", a, b, c)
    elseif op == 40 then  -- FORPREP
        detail = string.format(" sBx=%d", sbx)
    elseif op == 39 then  -- FORLOOP
        detail = string.format(" sBx=%d", sbx)
    end

    print(string.format("  [%3d] 0x%08X %-10s A=%3d B=%3d C=%3d%s",
        i, inst, name, a, b, c, detail))
end

-- 分析 JMP 跳转目标
print("\n=== JMP jump targets ===")
local jump_targets = {}
for i = 1, #target.code do
    if target.code[i] % 64 == 30 then
        local bx = target.code[i] >> 14
        local sbx = bx - 131071
        local tgt = i + sbx + 1
        jump_targets[tgt] = (jump_targets[tgt] or 0) + 1
    end
end
local jt_list = {}
for tgt, cnt in pairs(jump_targets) do
    table.insert(jt_list, {tgt=tgt, cnt=cnt})
end
table.sort(jt_list, function(a,b) return a.cnt > b.cnt end)
for i = 1, math.min(10, #jt_list) do
    local op = target.code[jt_list[i].tgt] % 64
    print(string.format("  target=[%d] count=%d op=%s", jt_list[i].tgt, jt_list[i].cnt, OP_NAMES[op] or "?"))
end

-- 分析 SETTABUP 的 A/B/C 分布
print("\n=== SETTABUP analysis ===")
local settabup_a = {}
local settabup_count = 0
for i = 1, #target.code do
    if target.code[i] % 64 == 8 then
        settabup_count = settabup_count + 1
        local a = (target.code[i] >> 6) & 0xFF
        settabup_a[a] = (settabup_a[a] or 0) + 1
    end
end
print("SETTABUP count: " .. settabup_count)
local sa_list = {}
for a, cnt in pairs(settabup_a) do table.insert(sa_list, {a=a, cnt=cnt}) end
table.sort(sa_list, function(a,b) return a.cnt > b.cnt end)
for i = 1, math.min(5, #sa_list) do
    print(string.format("  A=%d: %d", sa_list[i].a, sa_list[i].cnt))
end

-- 分析常量池
print("\n=== Constants (first 20) ===")
for i = 1, math.min(20, #target.k) do
    local v = target.k[i]
    print(string.format("  [%d] %s = %s", i, type(v), tostring(v):sub(1, 40)))
end
