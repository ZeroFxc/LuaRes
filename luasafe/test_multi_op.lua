local luac = require("luac")
local op48 = require("op48_junk")
local deop48 = require("deop48")

local func = load("print('hello world')")
local bc = string.dec(string.dump(func))
print("Original size: " .. #bc)

-- 多操作码注入
local p = luac.undump(bc, false)
op48.inject(p, {count = 100, mode = "blocks", multi = true})
local out = luac.dump(p)
print("After inject size: " .. #out)

-- 统计注入的操作码分布
local p2 = luac.undump(out, false)
local op_dist = {}
local function count_ops(pp)
    for i = 1, #pp.code do
        local op = pp.code[i] % 64
        op_dist[op] = (op_dist[op] or 0) + 1
    end
    for i = 1, #pp.p do count_ops(pp.p[i]) end
end
count_ops(p2)
print("Invalid ops injected:")
for op, cnt in pairs(op_dist) do
    if op > 46 then
        print(string.format("  OP_%d: %d", op, cnt))
    end
end

-- 验证注入后能执行
local ok, f = pcall(load, out)
print("Load after inject: " .. tostring(ok))
if ok then f() end

-- 去除所有无效操作码
local p3 = luac.undump(out, false)
local removed = deop48.remove(p3)
print("Removed: " .. removed .. " invalid ops")

local out2 = luac.dump(p3)
print("After remove size: " .. #out2)

-- 验证去除后能执行
local ok2, f2 = pcall(load, out2)
print("Load after remove: " .. tostring(ok2))
if ok2 then f2() end

-- 验证去除后没有无效操作码
local p4 = luac.undump(out2, false)
local invalid = 0
local function check(pp)
    for i = 1, #pp.code do
        if pp.code[i] % 64 > 46 then invalid = invalid + 1 end
    end
    for i = 1, #pp.p do check(pp.p[i]) end
end
check(p4)
print("Invalid ops remaining: " .. invalid)
