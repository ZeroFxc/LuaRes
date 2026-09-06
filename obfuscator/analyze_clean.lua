local luac = require("luac")

local f = io.open("E:/LuaRes/main(1)_clean2.lua", "rb")
local data = f:read("*a")
f:close()

local p = luac.undump(data, false)

-- Lua 5.3 标准操作码名称
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

-- 统计所有操作码分布
local op_count = {}
local total = 0
local invalid_ops = {}
local total_funcs = 0

-- 统计异常参数
local high_a_count = 0  -- A > 200
local high_bx_count = 0  -- Bx 异常大
local negative_sbx_count = 0  -- sBx 异常

-- 统计连续模式
local pattern_count = {}

local function analyze(pp, path)
    total_funcs = total_funcs + 1
    for i = 1, #pp.code do
        local inst = pp.code[i]
        local op = inst % 64
        total = total + 1
        op_count[op] = (op_count[op] or 0) + 1

        if op > 46 then
            table.insert(invalid_ops, {path=path, idx=i, raw=inst, op=op})
        end

        local a = (inst >> 6) & 0xFF
        if a > 200 then high_a_count = high_a_count + 1 end

        if op == 30 or op == 39 or op == 40 or op == 42 then  -- JMP/FORLOOP/FORPREP/TFORLOOP
            local bx = inst >> 14
            local sbx = bx - 131071
            if math.abs(sbx) > 10000 then high_bx_count = high_bx_count + 1 end
        end

        -- 统计连续 3 条指令的模式
        if i >= 3 then
            local p1 = pp.code[i-2] % 64
            local p2 = pp.code[i-1] % 64
            local p3 = op
            local key = string.format("%d-%d-%d", p1, p2, p3)
            pattern_count[key] = (pattern_count[key] or 0) + 1
        end
    end
    for i = 1, #pp.p do
        analyze(pp.p[i], path .. "/" .. i)
    end
end

analyze(p, "main")

print("=== Total ===")
print("Functions: " .. total_funcs)
print("Instructions: " .. total)
print("Invalid ops (>46): " .. #invalid_ops)
print("High A register (>200): " .. high_a_count)
print("High jump offset (>10000): " .. high_bx_count)

print("\n=== Opcode distribution (sorted) ===")
local list = {}
for op, cnt in pairs(op_count) do
    table.insert(list, {op=op, name=OP_NAMES[op] or "UNKNOWN", cnt=cnt, pct=cnt/total*100})
end
table.sort(list, function(a,b) return a.cnt > b.cnt end)
for i = 1, #list do
    local marker = ""
    if list[i].op > 46 then marker = " <-- INVALID" end
    print(string.format("  %2d %-10s %8d (%5.2f%%)%s", list[i].op, list[i].name, list[i].cnt, list[i].pct, marker))
end

print("\n=== Invalid op samples (first 20) ===")
for i = 1, math.min(20, #invalid_ops) do
    local s = invalid_ops[i]
    local a = (s.raw >> 6) & 0xFF
    local b = (s.raw >> 23) & 0x1FF
    local c = (s.raw >> 14) & 0x1FF
    print(string.format("  %s[%d] raw=0x%08X op=%d A=%d B=%d C=%d", s.path, s.idx, s.raw, s.op, a, b, c))
end

print("\n=== Top 20 instruction patterns (3-gram) ===")
local plist = {}
for k, v in pairs(pattern_count) do
    table.insert(plist, {key=k, cnt=v})
end
table.sort(plist, function(a,b) return a.cnt > b.cnt end)
for i = 1, math.min(20, #plist) do
    local parts = {}
    for n in string.gmatch(plist[i].key, "%d+") do
        table.insert(parts, OP_NAMES[tonumber(n)] or "OP"..n)
    end
    print(string.format("  %8d  %s", plist[i].cnt, table.concat(parts, " -> ")))
end

-- 检查是否有 OP_EXTRAARG (46) 以及它前面的指令
print("\n=== OP_EXTRAARG (46) analysis ===")
local extraarg_count = 0
local extraarg_prev = {}
local function check_extraarg(pp)
    for i = 1, #pp.code do
        if pp.code[i] % 64 == 46 then
            extraarg_count = extraarg_count + 1
            if i > 1 then
                local prev_op = pp.code[i-1] % 64
                extraarg_prev[prev_op] = (extraarg_prev[prev_op] or 0) + 1
            end
        end
    end
    for i = 1, #pp.p do check_extraarg(pp.p[i]) end
end
check_extraarg(p)
print("OP_EXTRAARG count: " .. extraarg_count)
for op, cnt in pairs(extraarg_prev) do
    print(string.format("  preceded by OP_%d (%s): %d", op, OP_NAMES[op] or "?", cnt))
end

-- 检查 LOADK (1) 的 Bx 范围
print("\n=== LOADK Bx range ===")
local loadk_bx_min = math.huge
local loadk_bx_max = 0
local loadk_count = 0
local function check_loadk(pp)
    for i = 1, #pp.code do
        if pp.code[i] % 64 == 1 then
            loadk_count = loadk_count + 1
            local bx = pp.code[i] >> 14
            if bx < loadk_bx_min then loadk_bx_min = bx end
            if bx > loadk_bx_max then loadk_bx_max = bx end
        end
    end
    for i = 1, #pp.p do check_loadk(pp.p[i]) end
end
check_loadk(p)
print("LOADK count: " .. loadk_count)
print("Bx range: " .. loadk_bx_min .. " - " .. loadk_bx_max)
