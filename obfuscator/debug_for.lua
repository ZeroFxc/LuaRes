local luac = require("luac")
local junk_jmp = require("junk_jmp")

-- 简单的 for 循环测试
local func = load("for i=1,3 do print(i) end print('done')")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

print("Original:")
for i = 1, #p.code do
    local inst = p.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[0]="MOVE",[1]="LOADK",[3]="LOADBOOL",[30]="JMP",[36]="CALL",[38]="RETURN",[39]="FORLOOP",[40]="FORPREP"}
    print(string.format("  [%d] 0x%08X %s A=%d sbx=%d", i, inst, names[op] or tostring(op), a, sbx))
end

junk_jmp.inject(p, {count = 3, recursive = false})

print("\nAfter inject:")
for i = 1, #p.code do
    local inst = p.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[0]="MOVE",[1]="LOADK",[3]="LOADBOOL",[30]="JMP",[36]="CALL",[38]="RETURN",[39]="FORLOOP",[40]="FORPREP"}
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
