local luac = require("luac")

local f = io.open("E:/LuaRes/fangtd.lua", "rb")
local data = f:read("*a")
f:close()

local p = luac.undump(data, false)

print("=== Main function upvalues analysis ===")
print("sizeupvalues: " .. p.sizeupvalues)
print("code count: " .. #p.code)

-- 分析前 30 个 upvalue 的特征
print("\n=== First 30 upvalues ===")
for i = 1, math.min(30, #p.upvalues) do
    local uv = p.upvalues[i]
    print(string.format("  [%d] instack=%d idx=%d name_len=%d name='%s'",
        i, uv.instack, uv.idx, #(uv.name or ""), (uv.name or ""):sub(1, 20)))
end

-- 统计 instack 分布
print("\n=== instack distribution ===")
local instack_dist = {}
for i = 1, #p.upvalues do
    local v = p.upvalues[i].instack
    instack_dist[v] = (instack_dist[v] or 0) + 1
end
local list = {}
for k, v in pairs(instack_dist) do table.insert(list, {k=k, v=v}) end
table.sort(list, function(a,b) return a.v > b.v end)
for i = 1, math.min(10, #list) do
    print(string.format("  instack=%d: %d (%.1f%%)", list[i].k, list[i].v, list[i].v / #p.upvalues * 100))
end

-- 统计 idx 分布
print("\n=== idx distribution (top 10) ===")
local idx_dist = {}
for i = 1, #p.upvalues do
    local v = p.upvalues[i].idx
    idx_dist[v] = (idx_dist[v] or 0) + 1
end
list = {}
for k, v in pairs(idx_dist) do table.insert(list, {k=k, v=v}) end
table.sort(list, function(a,b) return a.v > b.v end)
for i = 1, math.min(10, #list) do
    print(string.format("  idx=%d: %d", list[i].k, list[i].v))
end

-- 检查 main 函数的指令中是否有 GETUPVAL/SETUPVAL（引用 upvalue）
print("\n=== Main instructions referencing upvalues ===")
for i = 1, #p.code do
    local op = p.code[i] % 64
    if op == 5 or op == 9 then  -- GETUPVAL=5, SETUPVAL=9
        local a = (p.code[i] >> 6) & 0xFF
        local b = (p.code[i] >> 23) & 0x1FF
        print(string.format("  [%d] op=%d A=%d B=%d (upvalue idx=%d)", i, op, a, b, b))
    end
end

-- 检查子函数中是否有引用 main 的 upvalue
print("\n=== Sub-functions CLOSURE instructions ===")
for i = 1, #p.code do
    local op = p.code[i] % 64
    if op == 44 then  -- CLOSURE
        local a = (p.code[i] >> 6) & 0xFF
        local bx = p.code[i] >> 14
        print(string.format("  [%d] CLOSURE A=%d Bx=%d (proto idx=%d)", i, a, bx, bx))
    end
end

-- 检查子函数的 upvalues
print("\n=== Sub-function upvalues ===")
for i = 1, #p.p do
    local sub = p.p[i]
    print(string.format("  p[%d]: sizeupvalues=%d", i, sub.sizeupvalues))
    for j = 1, math.min(5, #sub.upvalues) do
        local uv = sub.upvalues[j]
        print(string.format("    [%d] instack=%d idx=%d", j, uv.instack, uv.idx))
    end
end
