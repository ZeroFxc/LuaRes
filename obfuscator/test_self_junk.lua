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
local function make_self(a, b, c)
    return (12) | ((a & 0xFF) << 6) | ((c & 0x1FF) << 14) | ((b & 0x1FF) << 23)
end

local func = load("print('hello')")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

-- 插入: LOADK R(3),0 + TEST R(3),0 + JMP sbx=1 + [SELF 垃圾]
local branch = {
    make_loadk(3, 0),
    make_test(3, 0),
    make_jmp(1),
    make_self(4, 4, 4),  -- 垃圾 SELF
}
for i = #branch, 1, -1 do
    table.insert(p.code, 3, branch[i])
end

print("With SELF junk:")
local names = {[1]="LOADK",[5]="GETUPVAL",[7]="GETTABLE",[12]="SELF",[30]="JMP",[34]="TEST",[36]="CALL",[38]="RETURN"}
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
