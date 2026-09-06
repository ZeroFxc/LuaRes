local luac = require("luac")
local junk_jmp = require("junk_jmp")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

-- mul 是 p[2]（add=p[1], mul=p[2], fib=p[3], main=p[4]）
-- 先看原始 mul
print("Original mul (p[2]):")
for i = 1, #p.p[2].code do
    local inst = p.p[2].code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[0]="MOVE",[1]="LOADK",[5]="GETUPVAL",[30]="JMP",[36]="CALL",[38]="RETURN",[39]="FORLOOP",[40]="FORPREP"}
    print(string.format("  [%d] 0x%08X %s A=%d sbx=%d", i, inst, names[op] or tostring(op), a, sbx))
end

-- 只在 mul 注入少量 JMP
junk_jmp.inject(p.p[2], {count = 3, recursive = false})

print("\nAfter inject mul (p[2]):")
for i = 1, #p.p[2].code do
    local inst = p.p[2].code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[0]="MOVE",[1]="LOADK",[5]="GETUPVAL",[30]="JMP",[36]="CALL",[38]="RETURN",[39]="FORLOOP",[40]="FORPREP"}
    print(string.format("  [%d] 0x%08X %s A=%d sbx=%d", i, inst, names[op] or tostring(op), a, sbx))
end

local out = luac.dump(p)
local ok, f = pcall(load, out)
print("\nLoad: " .. tostring(ok))
if ok then
    print("Execute:")
    f()
else
    print("Error: " .. tostring(f))
end
