-- analyze_vm.lua - deep analysis of VM protection (OP_48)
local luac = require("luac")

local input_path = arg[1] or "E:/LuaRes/layout.lua"

local f = io.open(input_path, "rb")
local data = f:read("*a")
f:close()

local proto = luac.undump(data, false)

print("=== OP_48 Deep Analysis ===")

-- Collect OP_48 instruction stats
local op48_count = 0
local op48_a_dist = {}
local op48_b_dist = {}
local op48_c_dist = {}
local op48_patterns = {}  -- context patterns

-- Find functions with high OP_48 density (VM interpreter functions)
local vm_funcs = {}

local function analyze(p, depth, path)
    local code = p.code
    local local_op48 = 0
    local local_loadk = 0
    local local_forprep = 0

    for i = 1, #code do
        local ins = code[i]
        local op = luac.GET_OPCODE(ins)

        if op == 48 then
            op48_count = op48_count + 1
            local_op48 = local_op48 + 1
            local a = luac.GETARG_A(ins)
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            op48_a_dist[a] = (op48_a_dist[a] or 0) + 1
            op48_b_dist[b] = (op48_b_dist[b] or 0) + 1
            op48_c_dist[c] = (op48_c_dist[c] or 0) + 1

            -- Context: what's before and after
            local before = (i > 1) and luac.GET_OPCODE(code[i-1]) or -1
            local after = (i < #code) and luac.GET_OPCODE(code[i+1]) or -1
            local pattern = string.format("%d->48->%d", before, after)
            op48_patterns[pattern] = (op48_patterns[pattern] or 0) + 1
        end
        if op == luac.OP_LOADK then local_loadk = local_loadk + 1 end
        if op == luac.OP_FORPREP then local_forprep = local_forprep + 1 end
    end

    if local_op48 > 10 then
        table.insert(vm_funcs, {
            path = path,
            op48 = local_op48,
            loadk = local_loadk,
            forprep = local_forprep,
            total = #code,
            density = local_op48 / #code * 100,
            k_count = #p.k,
        })
    end

    for i = 1, #p.p do
        analyze(p.p[i], depth + 1, path .. "/" .. i)
    end
end

analyze(proto, 0, "main")

print(string.format("Total OP_48 instructions: %d", op48_count))

-- OP_48 A/B/C distribution
print("\n=== OP_48 A register distribution (top 10) ===")
local sorted_a = {}
for a, count in pairs(op48_a_dist) do table.insert(sorted_a, {a=a, count=count}) end
table.sort(sorted_a, function(a,b) return a.count > b.count end)
for i=1, math.min(10, #sorted_a) do
    print(string.format("  A=%d: %d (%.1f%%)", sorted_a[i].a, sorted_a[i].count, sorted_a[i].count/op48_count*100))
end

print("\n=== OP_48 B distribution (top 10) ===")
local sorted_b = {}
for b, count in pairs(op48_b_dist) do table.insert(sorted_b, {b=b, count=count}) end
table.sort(sorted_b, function(a,b) return a.count > b.count end)
for i=1, math.min(10, #sorted_b) do
    print(string.format("  B=%d (0x%X): %d (%.1f%%)", sorted_b[i].b, sorted_b[i].b, sorted_b[i].count, sorted_b[i].count/op48_count*100))
end

print("\n=== OP_48 C distribution (top 10) ===")
local sorted_c = {}
for c, count in pairs(op48_c_dist) do table.insert(sorted_c, {c=c, count=count}) end
table.sort(sorted_c, function(a,b) return a.count > b.count end)
for i=1, math.min(10, #sorted_c) do
    print(string.format("  C=%d (0x%X): %d (%.1f%%)", sorted_c[i].c, sorted_c[i].c, sorted_c[i].count, sorted_c[i].count/op48_count*100))
end

-- Context patterns
print("\n=== OP_48 context patterns (top 15) ===")
local sorted_pat = {}
for pat, count in pairs(op48_patterns) do table.insert(sorted_pat, {pat=pat, count=count}) end
table.sort(sorted_pat, function(a,b) return a.count > b.count end)
for i=1, math.min(15, #sorted_pat) do
    local name = sorted_pat[i].pat:gsub("(%d+)", function(n)
        n = tonumber(n)
        if n == -1 then return "END" end
        return luac.OPCODE_NAMES[n+1] or ("OP_"..n)
    end)
    print(string.format("  %s: %d", name, sorted_pat[i].count))
end

-- VM interpreter functions
print("\n=== VM Interpreter Functions (OP_48 density > 10%) ===")
table.sort(vm_funcs, function(a,b) return a.density > b.density end)
for i=1, math.min(10, #vm_funcs) do
    local v = vm_funcs[i]
    print(string.format("  %s: %d ins, OP_48=%d (%.1f%%), LOADK=%d, FORPREP=%d, constants=%d",
        v.path, v.total, v.op48, v.density, v.loadk, v.forprep, v.k_count))
end

-- Dump first VM function's code for manual analysis
if #vm_funcs > 0 then
    print("\n=== First VM Function Code Dump (first 60 instructions) ===")
    -- Navigate to the function
    local function find_func(p, path_parts, idx)
        if idx > #path_parts then return p end
        return find_func(p.p[tonumber(path_parts[idx])], path_parts, idx+1)
    end
    local parts = {}
    for part in vm_funcs[1].path:gmatch("[^/]+") do table.insert(parts, part) end
    local vm_proto = find_func(proto, parts, 2)  -- skip "main"

    for i=1, math.min(60, #vm_proto.code) do
        local ins = vm_proto.code[i]
        local op = luac.GET_OPCODE(ins)
        local name = luac.OPCODE_NAMES[op+1] or ("OP_"..op)
        local extra = ""
        if op == luac.OP_LOADK then
            extra = string.format(" R%d -> K[%d]", luac.GETARG_A(ins), luac.GETARG_Bx(ins))
            if vm_proto.k[luac.GETARG_Bx(ins)+1] then
                local v = vm_proto.k[luac.GETARG_Bx(ins)+1]
                extra = extra .. " = " .. tostring(v)
            end
        elseif op == 48 then
            extra = string.format(" A=%d B=%d C=%d", luac.GETARG_A(ins), luac.GETARG_B(ins), luac.GETARG_C(ins))
        elseif op == luac.OP_JMP then
            extra = string.format(" sBx=%d", luac.GETARG_sBx(ins))
        elseif op == luac.OP_FORPREP or op == luac.OP_FORLOOP then
            extra = string.format(" A=%d sBx=%d", luac.GETARG_A(ins), luac.GETARG_sBx(ins))
        else
            extra = string.format(" A=%d B=%d C=%d", luac.GETARG_A(ins), luac.GETARG_B(ins), luac.GETARG_C(ins))
        end
        print(string.format("  [%3d] %-12s %s", i, name, extra))
    end
end

print("\nDone.")
