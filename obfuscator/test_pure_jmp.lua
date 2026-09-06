local luac = require("luac")

local function make_loadk(a, bx)
    return (1) | ((a & 0xFF) << 6) | ((bx & 0x3FFFF) << 14)
end
local function make_jmp(sbx)
    local bx = sbx + 131071
    return (30) | ((bx & 0x3FFFF) << 14)
end
local function make_unm(a)
    return (25) | ((a & 0xFF) << 6) | ((a & 0x1FF) << 14) | ((a & 0x1FF) << 23)
end

-- 测试1: 纯 JMP sbx=1，跳过 UNM
print("=== Test 1: pure JMP sbx=1 ===")
local func = load("print('hello')")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

-- 在位置 3 插入 JMP + UNM
local branch = {
    make_jmp(1),
    make_unm(4),
}
for i = #branch, 1, -1 do
    table.insert(p.code, 3, branch[i])
end

local names = {[1]="LOADK",[5]="GETUPVAL",[7]="GETTABLE",[25]="UNM",[30]="JMP",[36]="CALL",[38]="RETURN"}
for i = 1, #p.code do
    local inst = p.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local sbx = bx - 131071
    local extra = ""
    if op == 30 then extra = string.format(" sbx=%d ->%d", sbx, i+sbx+1) end
    print(string.format("  [%d] 0x%08X %-8s A=%d%s", i, inst, names[op] or tostring(op), a, extra))
end

local out = luac.dump(p)
local ok, f = pcall(load, out)
print("Load: " .. tostring(ok))
if ok then
    local exec_ok, err = pcall(f)
    print("Execute: " .. tostring(exec_ok))
    if not exec_ok then print("Error: " .. tostring(err)) end
end

-- 测试2: JMP sbx=0（跳到下一条，即 UNM 本身）
print("\n=== Test 2: JMP sbx=0 (jump to UNM itself) ===")
local p2 = luac.undump(bc, false)
local branch2 = {
    make_jmp(0),
    make_unm(4),
}
for i = #branch2, 1, -1 do
    table.insert(p2.code, 3, branch2[i])
end
local out2 = luac.dump(p2)
local ok2, f2 = pcall(load, out2)
print("Load: " .. tostring(ok2))
if ok2 then
    local exec_ok, err = pcall(f2)
    print("Execute: " .. tostring(exec_ok))
    if not exec_ok then print("Error: " .. tostring(err)) end
end

-- 测试3: JMP sbx=2（跳过 UNM 和 LOADK）
print("\n=== Test 3: JMP sbx=2 (skip UNM+LOADK) ===")
local p3 = luac.undump(bc, false)
local branch3 = {
    make_jmp(2),
    make_unm(4),
}
for i = #branch3, 1, -1 do
    table.insert(p3.code, 3, branch3[i])
end
local out3 = luac.dump(p3)
local ok3, f3 = pcall(load, out3)
print("Load: " .. tostring(ok3))
if ok3 then
    local exec_ok, err = pcall(f3)
    print("Execute: " .. tostring(exec_ok))
    if not exec_ok then print("Error: " .. tostring(err)) end
end
