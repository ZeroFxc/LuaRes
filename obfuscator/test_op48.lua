local luac = require("luac")

-- 编译 hello world
local func = load("print('hello world')")
local bc = string.dec(string.dump(func))
print("Original size: " .. #bc)

local p = luac.undump(bc, false)
print("Original code count: " .. #p.code)
print("Original instructions:")
for i = 1, #p.code do
    local op = p.code[i] % 64
    print(string.format("  [%d] 0x%08X op=%d", i, p.code[i], op))
end

-- 构造 OP_48 垃圾指令（模仿 main(1).lua 的特征）
-- A=127, B/C 随机, 低8位=0xF0 (op=48)
local function make_op48()
    local a = 127
    local b = math.random(256, 511)  -- 模仿样本中的 B 值
    local c = math.random(0, 200)
    -- 指令格式: A(8) | B(9) | C(9) | op(6)
    -- 小端: 低字节是 op(6) + C 的低2位
    local inst = (a << 6) | (b << 23) | (c << 14) | 48
    return inst
end

-- 测试1: 在 code 末尾插入 10 个 OP_48
print("\n=== Test 1: append 10 OP_48 at end ===")
local p1 = luac.undump(bc, false)
for i = 1, 10 do
    table.insert(p1.code, make_op48())
end
p1.lineinfo = {}  -- 清空 lineinfo，避免数量不匹配
local out1 = luac.dump(p1)
print("Output size: " .. #out1)
local ok1, f1 = pcall(load, out1)
print("Load: " .. tostring(ok1))
if ok1 then
    io.write("Execute: ")
    f1()
else
    print("  Error: " .. tostring(f1))
end

-- 测试2: 在 code 中间插入 OP_48（在 RETURN 之前）
print("\n=== Test 2: insert OP_48 before RETURN ===")
local p2 = luac.undump(bc, false)
-- 找到 RETURN 指令（op=38），在它之前插入 5 个 OP_48
local insert_pos = #p2.code  -- 默认末尾
for i = 1, #p2.code do
    if p2.code[i] % 64 == 38 then
        insert_pos = i
        break
    end
end
print("Insert at position: " .. insert_pos)
for i = 1, 5 do
    table.insert(p2.code, insert_pos, make_op48())
end
p2.lineinfo = {}
local out2 = luac.dump(p2)
print("Output size: " .. #out2)
local ok2, f2 = pcall(load, out2)
print("Load: " .. tostring(ok2))
if ok2 then
    io.write("Execute: ")
    f2()
else
    print("  Error: " .. tostring(f2))
end

-- 测试3: 大量插入 100 个 OP_48
print("\n=== Test 3: insert 100 OP_48 ===")
local p3 = luac.undump(bc, false)
for i = 1, 100 do
    table.insert(p3.code, make_op48())
end
p3.lineinfo = {}
local out3 = luac.dump(p3)
print("Output size: " .. #out3)
local ok3, f3 = pcall(load, out3)
print("Load: " .. tostring(ok3))
if ok3 then
    io.write("Execute: ")
    f3()
else
    print("  Error: " .. tostring(f3))
end

-- 测试4: 连续 OP_48 块（模仿 main(1).lua 中连续 4 个 OP_48）
print("\n=== Test 4: continuous OP_48 block in middle ===")
local p4 = luac.undump(bc, false)
-- 在第 2 条指令后插入连续 8 个 OP_48
for i = 1, 8 do
    table.insert(p4.code, 3, make_op48())
end
p4.lineinfo = {}
local out4 = luac.dump(p4)
print("Output size: " .. #out4)
local ok4, f4 = pcall(load, out4)
print("Load: " .. tostring(ok4))
if ok4 then
    io.write("Execute: ")
    f4()
else
    print("  Error: " .. tostring(f4))
end

-- 写入测试文件
local fout = io.open("E:/LuaRes/luasafe/hello_op48_test.lua", "wb")
fout:write(out2)  -- 用测试2的结果
fout:close()
print("\nWritten test file: E:/LuaRes/luasafe/hello_op48_test.lua")
