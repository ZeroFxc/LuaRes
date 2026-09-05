local luac = require("luac")

-- 原生编译一个包含 if 语句的函数
local func = load("local x=1 if x then print('yes') end print('done')")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

print("Native if statement:")
for i = 1, #p.code do
    local inst = p.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local b = (inst >> 23) & 0x1FF
    local c = (inst >> 14) & 0x1FF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[0]="MOVE",[1]="LOADK",[5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[30]="JMP",[34]="TEST",[36]="CALL",[38]="RETURN"}
    local extra = ""
    if op == 30 then extra = string.format(" sbx=%d ->%d", sbx, i+sbx+1) end
    print(string.format("  [%d] 0x%08X %-8s A=%d B=%d C=%d%s", i, inst, names[op] or tostring(op), a, b, c, extra))
end
print("constants:")
for i = 1, #p.k do
    print(string.format("  k[%d]: %s", i-1, tostring(p.k[i])))
end

-- 现在手动构造相同的结构，用我的 make_test/make_jmp
print("\n--- Manual construction test ---")
local func2 = load("print('hello')")
local bc2 = string.dec(string.dump(func2))
local p2 = luac.undump(bc2, false)

print("Before:")
for i = 1, #p2.code do
    local inst = p2.code[i]
    local op = inst % 64
    print(string.format("  [%d] 0x%08X op=%d", i, inst, op))
end

-- 手动插入: LOADK R(3),0 + TEST R(3),0 + JMP sbx=1 + [1 junk]
local function make_loadk(a, bx)
    return (1) | ((a & 0xFF) << 6) | ((bx & 0x3FFFF) << 14)
end
local function make_test(a, c)
    return (34) | ((a & 0xFF) << 6) | ((c & 0x1FF) << 14)
end
local function make_jmp(sbx)
    local bx = sbx + 131071
    return (30) | ((bx & 0x3FFFF) << 14)
end

-- 在位置 3 插入
local branch = {
    make_loadk(3, 0),
    make_test(3, 0),
    make_jmp(1),  -- 跳过 1 条垃圾
    make_loadk(4, 0),  -- 垃圾
}
for i = #branch, 1, -1 do
    table.insert(p2.code, 3, branch[i])
end

print("\nAfter manual insert:")
for i = 1, #p2.code do
    local inst = p2.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[1]="LOADK",[5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[30]="JMP",[34]="TEST",[36]="CALL",[38]="RETURN"}
    local extra = ""
    if op == 30 then extra = string.format(" sbx=%d ->%d", sbx, i+sbx+1) end
    print(string.format("  [%d] 0x%08X %-8s A=%d%s", i, inst, names[op] or tostring(op), a, extra))
end

local out = luac.dump(p2)
local ok, f = pcall(load, out)
print("\nLoad: " .. tostring(ok))
if ok then
    print("Execute:")
    f()
else
    print("Error: " .. tostring(f))
end
