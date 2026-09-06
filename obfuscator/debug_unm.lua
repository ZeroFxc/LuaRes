local luac = require("luac")

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

-- 用 UNM 作为垃圾指令
local func = load("print('hello')")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

local unm = 25 | ((4 & 0xFF) << 6) | ((4 & 0x1FF) << 14) | ((4 & 0x1FF) << 23)

local branch = {
    make_loadk(3, 0),
    make_test(3, 0),
    make_jmp(1),
    unm,
}
for i = #branch, 1, -1 do
    table.insert(p.code, 3, branch[i])
end

print("Before dump:")
local names = {[1]="LOADK",[5]="GETUPVAL",[7]="GETTABLE",[25]="UNM",[30]="JMP",[34]="TEST",[36]="CALL",[38]="RETURN"}
for i = 1, #p.code do
    local inst = p.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local b = (inst >> 23) & 0x1FF
    local c = (inst >> 14) & 0x1FF
    local bx = inst >> 14
    local sbx = bx - 131071
    local extra = ""
    if op == 30 then extra = string.format(" sbx=%d ->%d", sbx, i+sbx+1) end
    print(string.format("  [%d] 0x%08X %-8s A=%d B=%d C=%d%s", i, inst, names[op] or tostring(op), a, b, c, extra))
end

print("constants:")
for i = 1, #p.k do
    print(string.format("  k[%d]: %s (%s)", i-1, tostring(p.k[i]), type(p.k[i])))
end

local out = luac.dump(p)

-- 重新加载验证
local p2 = luac.undump(out, false)
print("\nAfter dump+undump:")
for i = 1, #p2.code do
    local inst = p2.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local sbx = bx - 131071
    local extra = ""
    if op == 30 then extra = string.format(" sbx=%d ->%d", sbx, i+sbx+1) end
    print(string.format("  [%d] 0x%08X %-8s A=%d%s", i, inst, names[op] or tostring(op), a, extra))
end

-- 测试：把 UNM 换成 MOVE（安全的），看看是否正常
print("\n--- Replace UNM with MOVE ---")
local p3 = luac.undump(bc, false)
local move = 0 | ((4 & 0xFF) << 6) | ((5 & 0x1FF) << 23)
local branch2 = {
    make_loadk(3, 0),
    make_test(3, 0),
    make_jmp(1),
    move,
}
for i = #branch2, 1, -1 do
    table.insert(p3.code, 3, branch2[i])
end
local out3 = luac.dump(p3)
local ok3, f3 = pcall(load, out3)
print("MOVE: load=" .. tostring(ok3))
if ok3 then
    local exec_ok, err = pcall(f3)
    print("MOVE: exec=" .. tostring(exec_ok))
    if not exec_ok then print("Error: " .. tostring(err)) end
end

-- 测试：UNM 但用高寄存器 A=10
print("\n--- UNM with A=10 ---")
local p4 = luac.undump(bc, false)
p4.maxstacksize = 15
local unm10 = 25 | ((10 & 0xFF) << 6) | ((10 & 0x1FF) << 14) | ((10 & 0x1FF) << 23)
local branch4 = {
    make_loadk(3, 0),
    make_test(3, 0),
    make_jmp(1),
    unm10,
}
for i = #branch4, 1, -1 do
    table.insert(p4.code, 3, branch4[i])
end
local out4 = luac.dump(p4)
local ok4, f4 = pcall(load, out4)
print("UNM A=10: load=" .. tostring(ok4))
if ok4 then
    local exec_ok, err = pcall(f4)
    print("UNM A=10: exec=" .. tostring(exec_ok))
    if not exec_ok then print("Error: " .. tostring(err)) end
end
