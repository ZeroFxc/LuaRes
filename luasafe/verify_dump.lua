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
local function make_newtable(a)
    return (11) | ((a & 0xFF) << 6)
end

local func = load("print('hello')")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

-- 用 NEWTABLE 作为垃圾（操作码 11，不是 10）
local branch = {
    make_loadk(3, 0),
    make_test(3, 0),
    make_jmp(1),
    make_newtable(4),
}
for i = #branch, 1, -1 do
    table.insert(p.code, 3, branch[i])
end

print("Before dump:")
local names = {[1]="LOADK",[5]="GETUPVAL",[7]="GETTABLE",[11]="NEWTABLE",[30]="JMP",[34]="TEST",[36]="CALL",[38]="RETURN"}
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

-- 比较
print("\nMatch: " .. tostring(#p.code == #p2.code))
for i = 1, #p.code do
    if p.code[i] ~= p2.code[i] then
        print(string.format("  MISMATCH at [%d]: 0x%08X vs 0x%08X", i, p.code[i], p2.code[i]))
    end
end

local ok, f = pcall(load, out)
print("\nLoad: " .. tostring(ok))
if ok then
    local exec_ok, err = pcall(f)
    print("Execute: " .. tostring(exec_ok))
    if not exec_ok then print("Error: " .. tostring(err)) end
end
