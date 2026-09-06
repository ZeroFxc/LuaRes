-- 直接二进制扫描 main(1).lua 中的 OP_48 指令
-- 不经过 luac.undump，避免常量池混淆导致的解析错误

local f = io.open("E:/LuaRes/main(1).lua", "rb")
local data = f:read("*a")
f:close()

print("File size: " .. #data)

-- 扫描所有 4 字节对齐的位置，找操作码为 48 的指令
-- 指令格式: 32位小端整数，低6位是操作码
local op48_list = {}
local op48_a_dist = {}
local op48_raw_dist = {}
local total_scanned = 0

-- 从 header 之后开始扫描（跳过 33 字节 andlua header + 1 字节 upvalue count）
-- 但为了简单，从偏移 64 开始扫描整个文件
for pos = 64, #data - 4, 4 do
    local b0 = data:byte(pos)
    local b1 = data:byte(pos+1)
    local b2 = data:byte(pos+2)
    local b3 = data:byte(pos+3)
    local inst = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    local op = inst & 0x3F
    total_scanned = total_scanned + 1
    if op == 48 then
        local a = (inst >> 6) & 0xFF
        local c = (inst >> 14) & 0x1FF
        local b = (inst >> 23) & 0x1FF
        table.insert(op48_list, {pos=pos, raw=inst, a=a, b=b, c=c})
        op48_a_dist[a] = (op48_a_dist[a] or 0) + 1
        op48_raw_dist[inst] = (op48_raw_dist[inst] or 0) + 1
    end
end

print("Scanned positions: " .. total_scanned)
print("OP_48 found: " .. #op48_list)
print(string.format("Percentage: %.2f%%", #op48_list / total_scanned * 100))

print("\n=== OP_48 A register distribution (top 10) ===")
local a_list = {}
for a, cnt in pairs(op48_a_dist) do table.insert(a_list, {a=a, cnt=cnt}) end
table.sort(a_list, function(x,y) return x.cnt > y.cnt end)
for i = 1, math.min(10, #a_list) do
    print(string.format("  A=%d: %d (%.1f%%)", a_list[i].a, a_list[i].cnt, a_list[i].cnt / #op48_list * 100))
end

print("\n=== OP_48 raw value distribution (top 10) ===")
local raw_list = {}
for raw, cnt in pairs(op48_raw_dist) do table.insert(raw_list, {raw=raw, cnt=cnt}) end
table.sort(raw_list, function(x,y) return x.cnt > y.cnt end)
for i = 1, math.min(10, #raw_list) do
    local r = raw_list[i].raw
    local a = (r >> 6) & 0xFF
    local c = (r >> 14) & 0x1FF
    local b = (r >> 23) & 0x1FF
    print(string.format("  raw=0x%08X A=%d B=%d C=%d: %d", r, a, b, c, raw_list[i].cnt))
end

print("\n=== OP_48 samples (first 15) ===")
for i = 1, math.min(15, #op48_list) do
    local s = op48_list[i]
    -- 看前后的指令
    local prev_raw = 0
    local next_raw = 0
    if s.pos > 4 then
        local p0 = data:byte(s.pos-4)
        local p1 = data:byte(s.pos-3)
        local p2 = data:byte(s.pos-2)
        local p3 = data:byte(s.pos-1)
        prev_raw = p0 | (p1 << 8) | (p2 << 16) | (p3 << 24)
    end
    if s.pos + 8 <= #data then
        local n0 = data:byte(s.pos+4)
        local n1 = data:byte(s.pos+5)
        local n2 = data:byte(s.pos+6)
        local n3 = data:byte(s.pos+7)
        next_raw = n0 | (n1 << 8) | (n2 << 16) | (n3 << 24)
    end
    print(string.format("  pos=%d raw=0x%08X A=%d B=%d C=%d | prev_op=%d next_op=%d",
        s.pos, s.raw, s.a, s.b, s.c, prev_raw & 0x3F, next_raw & 0x3F))
end
