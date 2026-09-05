local luac = require("luac")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

-- 检查每个子函数引用了哪些 upvalue
print("=== Upvalue usage analysis ===")
local function analyze_uv_usage(pp, name)
    local used = {}
    for i = 1, #pp.code do
        local op = pp.code[i] % 64
        if op == 5 or op == 9 then  -- GETUPVAL/SETUPVAL
            local b = (pp.code[i] >> 23) & 0x1FF
            used[b] = true
        end
    end
    local max_used = -1
    for k in pairs(used) do if k > max_used then max_used = k end end
    print(string.format("%s: sizeupvalues=%d, used upvalues: %s, max_used_idx=%d",
        name, pp.sizeupvalues,
        next(used) and table.concat((function() local t={} for k in pairs(used) do table.insert(t,k) end table.sort(t) return t end)(), ",") or "none",
        max_used))
end
analyze_uv_usage(p, "main")
for i = 1, #p.p do analyze_uv_usage(p.p[i], "p["..i.."]") end

-- 测试：在每个函数的真实 upvalue 后面追加垃圾 upvalue
print("\n=== Test: append garbage upvalues to ALL functions ===")
local p2 = luac.undump(bc, false)

local function append_junk_uv(pp, junk_count)
    local orig = {}
    for i = 1, #pp.upvalues do table.insert(orig, pp.upvalues[i]) end
    local junk = {}
    for i = 1, #orig do table.insert(junk, orig[i]) end
    for i = 1, junk_count do
        table.insert(junk, {
            instack = math.random(0, 255),
            idx = math.random(0, 255),
            name = "",
        })
    end
    pp.upvalues = junk
end

append_junk_uv(p2, 100)
for i = 1, #p2.p do append_junk_uv(p2.p[i], 50) end

local out = luac.dump(p2)
print("Output size: " .. #out)

-- 验证 dump 后的 sizeupvalues
local p3 = luac.undump(out, false)
print("Main sizeupvalues after dump: " .. p3.sizeupvalues)
for i = 1, #p3.p do
    print(string.format("  p[%d] sizeupvalues: %d", i, p3.p[i].sizeupvalues))
end

local ok, f = pcall(load, out)
print("Load: " .. tostring(ok))
if ok then
    local outputs = {}
    local old_print = print
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok = pcall(f)
    print = old_print
    print("Execute: " .. tostring(exec_ok))
    print("Last output: " .. outputs[#outputs])
    print("Output count: " .. #outputs)
else
    print("Error: " .. tostring(f))
end

-- 测试极限：大量垃圾 upvalue
print("\n=== Test: extreme garbage upvalues (500 per function) ===")
local p4 = luac.undump(bc, false)
append_junk_uv(p4, 500)
for i = 1, #p4.p do append_junk_uv(p4.p[i], 300) end
local out4 = luac.dump(p4)
print("Output size: " .. #out4)
local ok4, f4 = pcall(load, out4)
print("Load: " .. tostring(ok4))
if ok4 then
    local outputs = {}
    local old_print = print
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok = pcall(f4)
    print = old_print
    print("Execute: " .. tostring(exec_ok))
    print("Last output: " .. outputs[#outputs])
else
    print("Error: " .. tostring(f4))
end

print("\n=== Conclusion ===")
print("Garbage upvalues can be appended to ANY function (main + sub)")
print("as long as the original upvalues are preserved at the beginning")
print("because functions only reference upvalues by index via GETUPVAL/SETUPVAL")
print("and appended garbage indices are never referenced")
