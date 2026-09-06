local luac = require("luac")

-- 编译多子函数测试脚本
local func, err = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
if not func then
    print("compile error: " .. tostring(err))
    os.exit(1)
end
local bc = string.dec(string.dump(func))
print("Original size: " .. #bc)

local p = luac.undump(bc, false)
print("Main code: " .. #p.code .. ", sub funcs: " .. #p.p)
for i = 1, #p.p do
    print(string.format("  p[%d]: code=%d upvalues=%d", i, #p.p[i].code, p.p[i].sizeupvalues))
end

local function make_op48()
    local a = 127
    local b = math.random(256, 511)
    local c = math.random(0, 200)
    return (a << 6) | (b << 23) | (c << 14) | 48
end

-- 测试1: 在每个子函数末尾注入 OP_48
print("\n=== Test 1: OP_48 at end of each sub function ===")
local p1 = luac.undump(bc, false)
for i = 1, #p1.p do
    for j = 1, 20 do
        table.insert(p1.p[i].code, make_op48())
    end
    p1.p[i].lineinfo = {}
end
-- main 也注入
for i = 1, 20 do table.insert(p1.code, make_op48()) end
p1.lineinfo = {}

local out1 = luac.dump(p1)
print("Output size: " .. #out1)
local ok1, f1 = pcall(load, out1)
print("Load: " .. tostring(ok1))
if ok1 then
    -- 捕获输出
    local outputs = {}
    local old_print = print
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok = pcall(f1)
    print = old_print
    print("Execute: " .. tostring(exec_ok))
    print("Last output: " .. outputs[#outputs])
    print("Output count: " .. #outputs)
else
    print("Error: " .. tostring(f1))
end

-- 测试2: 在子函数最后一个 RETURN 之后注入 OP_48
print("\n=== Test 2: OP_48 after last RETURN in each sub function ===")
local p2 = luac.undump(bc, false)
local function inject_after_last_return(pp)
    local last_ret = 0
    for i = #pp.code, 1, -1 do
        if pp.code[i] % 64 == 38 or pp.code[i] % 64 == 37 then
            last_ret = i
            break
        end
    end
    if last_ret > 0 then
        for i = 1, 15 do
            table.insert(pp.code, last_ret + 1, make_op48())
        end
    end
    pp.lineinfo = {}
end
inject_after_last_return(p2)
for i = 1, #p2.p do inject_after_last_return(p2.p[i]) end

local out2 = luac.dump(p2)
print("Output size: " .. #out2)
local ok2, f2 = pcall(load, out2)
print("Load: " .. tostring(ok2))
if ok2 then
    local outputs = {}
    local old_print = print
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok = pcall(f2)
    print = old_print
    print("Execute: " .. tostring(exec_ok))
    print("Last output: " .. outputs[#outputs])
else
    print("Error: " .. tostring(f2))
end

-- 测试3: 在子函数中注入垃圾 upvalue（预期会崩溃）
print("\n=== Test 3: garbage upvalues in sub function (expected to crash) ===")
local p3 = luac.undump(bc, false)
-- 在第一个子函数中注入垃圾 upvalue
if #p3.p > 0 then
    local sub = p3.p[1]
    local orig_count = sub.sizeupvalues
    print("Original sub upvalues: " .. orig_count)
    -- 注入垃圾 upvalue
    local junk_uv = {}
    for i = 1, orig_count do
        table.insert(junk_uv, sub.upvalues[i])
    end
    for i = 1, 50 do
        table.insert(junk_uv, {
            instack = math.random(2, 255),
            idx = math.random(0, 255),
            name = "",
        })
    end
    sub.upvalues = junk_uv
    sub.sizeupvalues = #junk_uv
    print("After injection: " .. sub.sizeupvalues)
end

local out3 = luac.dump(p3)
print("Output size: " .. #out3)
local ok3, f3 = pcall(load, out3)
print("Load: " .. tostring(ok3))
if ok3 then
    local outputs = {}
    local old_print = print
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok, exec_err = pcall(f3)
    print = old_print
    print("Execute: " .. tostring(exec_ok))
    if not exec_ok then
        print("Error: " .. tostring(exec_err))
    else
        print("Last output: " .. outputs[#outputs])
    end
else
    print("Error: " .. tostring(f3))
end

-- 测试4: 只在 main 函数注入垃圾 upvalue，子函数不动（正确做法）
print("\n=== Test 4: garbage upvalues only in main (correct) ===")
local p4 = luac.undump(bc, false)
-- main 注入垃圾 upvalue
local main_orig = p4.sizeupvalues
print("Main original upvalues: " .. main_orig)
local junk_uv = {}
for i = 1, main_orig do table.insert(junk_uv, p4.upvalues[i]) end
for i = 1, 200 do
    table.insert(junk_uv, {
        instack = math.random(0, 255),
        idx = math.random(0, 255),
        name = "",
    })
end
p4.upvalues = junk_uv
p4.sizeupvalues = #junk_uv
print("Main after injection: " .. p4.sizeupvalues)

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
    print("Output count: " .. #outputs)
else
    print("Error: " .. tostring(f4))
end

print("\n=== Conclusion ===")
print("OP_48: safe to inject in any function at end/after last RETURN")
print("Garbage upvalues: ONLY safe in main function, NOT in sub functions")
print("Sub function upvalues are referenced by CLOSURE instructions, must be preserved")
