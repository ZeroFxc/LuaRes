local luac = require("luac")

-- 有跳转的代码（for 循环）
local func = load("for i=1,3 do print('loop'..i) end print('done')")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

print("Original code count: " .. #p.code)
for i = 1, #p.code do
    local op = p.code[i] % 64
    print(string.format("  [%d] 0x%08X op=%d", i, p.code[i], op))
end

local function op48()
    local a = 127
    local b = math.random(256, 511)
    local c = math.random(0, 200)
    return (a << 6) | (b << 23) | (c << 14) | 48
end

-- 测试1: 末尾插入（不影响跳转）
print("\n=== Test 1: append 20 OP_48 ===")
local p1 = luac.undump(bc, false)
for i = 1, 20 do table.insert(p1.code, op48()) end
p1.lineinfo = {}
local out1 = luac.dump(p1)
local ok1, f1 = pcall(load, out1)
print("load=" .. tostring(ok1))
if ok1 then f1() end

-- 测试2: 在 FORPREP 之前插入（会改变 FORLOOP 的跳转目标）
print("\n=== Test 2: insert before FORPREP (breaks jump) ===")
local p2 = luac.undump(bc, false)
-- 找到 FORPREP (op=40)
local forprep_pos = 0
for i = 1, #p2.code do
    if p2.code[i] % 64 == 40 then forprep_pos = i; break end
end
print("FORPREP at position: " .. forprep_pos)
if forprep_pos > 0 then
    for i = 1, 3 do table.insert(p2.code, forprep_pos, op48()) end
end
p2.lineinfo = {}
local out2 = luac.dump(p2)
local ok2, f2 = pcall(load, out2)
print("load=" .. tostring(ok2))
if ok2 then
    f2()
else
    print("  Error: " .. tostring(f2))
end

-- 测试3: 在 RETURN 之后插入（安全位置）
print("\n=== Test 3: insert after RETURN (safe) ===")
local p3 = luac.undump(bc, false)
-- 找到最后一个 RETURN (op=38)
local last_return = 0
for i = #p3.code, 1, -1 do
    if p3.code[i] % 64 == 38 then last_return = i; break end
end
print("Last RETURN at: " .. last_return)
for i = 1, 10 do table.insert(p3.code, last_return + 1, op48()) end
p3.lineinfo = {}
local out3 = luac.dump(p3)
local ok3, f3 = pcall(load, out3)
print("load=" .. tostring(ok3))
if ok3 then f3() end

-- 测试4: 在基本块内部插入（CALL 之后，下一条指令之前）
print("\n=== Test 4: insert inside basic block (after CALL) ===")
local p4 = luac.undump(bc, false)
-- 找到第一个 CALL (op=36)
local call_pos = 0
for i = 1, #p4.code do
    if p4.code[i] % 64 == 36 then call_pos = i; break end
end
print("First CALL at: " .. call_pos)
if call_pos > 0 then
    for i = 1, 5 do table.insert(p4.code, call_pos + 1, op48()) end
end
p4.lineinfo = {}
local out4 = luac.dump(p4)
local ok4, f4 = pcall(load, out4)
print("load=" .. tostring(ok4))
if ok4 then
    f4()
else
    print("  Error: " .. tostring(f4))
end

print("\n=== Conclusion ===")
print("OP_48 is junk instruction, andlua VM ignores it")
print("Safe insertion positions: after RETURN, at end of code")
print("Unsafe positions: before jump targets (FORPREP, JMP target)")
print("Need to adjust jump offsets when inserting in middle")
