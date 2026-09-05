local luac = require("luac")

local f = io.open("E:/LuaRes/main(1).lua", "rb")
local data = f:read("*a")
f:close()

local p = luac.undump(data, false)

-- 统计 OP_48 的特征
local op48_count = 0
local op48_samples = {}
local op48_a_dist = {}
local op48_raw_dist = {}
local total_inst = 0

local function analyze(pp)
    for i = 1, #pp.code do
        total_inst = total_inst + 1
        local inst = pp.code[i]
        local op = inst % 64
        if op == 48 then
            op48_count = op48_count + 1
            local a = (inst >> 6) % 256
            local c = (inst >> 14) % 512
            local b = (inst >> 23) % 512
            local bx = inst >> 14
            local sbx = bx - 131071
            op48_a_dist[a] = (op48_a_dist[a] or 0) + 1
            op48_raw_dist[inst] = (op48_raw_dist[inst] or 0) + 1
            if #op48_samples < 20 then
                table.insert(op48_samples, {
                    idx = i,
                    raw = inst,
                    a = a, b = b, c = c,
                    bx = bx, sbx = sbx,
                    prev = i > 1 and pp.code[i-1] or nil,
                    next = i < #pp.code and pp.code[i+1] or nil,
                })
            end
        end
    end
    for i = 1, #pp.p do analyze(pp.p[i]) end
end
analyze(p)

print("Total instructions: " .. total_inst)
print("OP_48 count: " .. op48_count)
print(string.format("OP_48 percentage: %.2f%%", op48_count / total_inst * 100))

print("\n=== OP_48 A register distribution (top 10) ===")
local a_list = {}
for a, cnt in pairs(op48_a_dist) do table.insert(a_list, {a=a, cnt=cnt}) end
table.sort(a_list, function(x,y) return x.cnt > y.cnt end)
for i = 1, math.min(10, #a_list) do
    print(string.format("  A=%d: %d (%.1f%%)", a_list[i].a, a_list[i].cnt, a_list[i].cnt / op48_count * 100))
end

print("\n=== OP_48 raw value distribution (top 10) ===")
local raw_list = {}
for raw, cnt in pairs(op48_raw_dist) do table.insert(raw_list, {raw=raw, cnt=cnt}) end
table.sort(raw_list, function(x,y) return x.cnt > y.cnt end)
for i = 1, math.min(10, #raw_list) do
    local r = raw_list[i].raw
    local a = (r >> 6) % 256
    local c = (r >> 14) % 512
    local b = (r >> 23) % 512
    print(string.format("  raw=0x%08X A=%d B=%d C=%d: %d", r, a, b, c, raw_list[i].cnt))
end

print("\n=== OP_48 samples (first 10) ===")
for i = 1, math.min(10, #op48_samples) do
    local s = op48_samples[i]
    local prev_op = s.prev and (s.prev % 64) or -1
    local next_op = s.next and (s.next % 64) or -1
    print(string.format("  [%d] raw=0x%08X A=%d B=%d C=%d | prev_op=%d next_op=%d",
        s.idx, s.raw, s.a, s.b, s.c, prev_op, next_op))
end

-- 检查 OP_48 是否总是出现在特定指令之后
print("\n=== OP_48 context: what opcode precedes OP_48? ===")
local prev_dist = {}
local function scan_context(pp)
    for i = 2, #pp.code do
        if pp.code[i] % 64 == 48 then
            local prev_op = pp.code[i-1] % 64
            prev_dist[prev_op] = (prev_dist[prev_op] or 0) + 1
        end
    end
    for i = 1, #pp.p do scan_context(pp.p[i]) end
end
scan_context(p)
local prev_list = {}
for op, cnt in pairs(prev_dist) do table.insert(prev_list, {op=op, cnt=cnt}) end
table.sort(prev_list, function(x,y) return x.cnt > y.cnt end)
for i = 1, math.min(10, #prev_list) do
    print(string.format("  prev OP_%d: %d", prev_list[i].op, prev_list[i].cnt))
end
