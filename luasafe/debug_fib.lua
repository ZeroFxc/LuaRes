local luac = require("luac")
local junk_jmp = require("junk_jmp")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

-- fib 是 p[3]
print("Original fib (p[3]):")
for i = 1, #p.p[3].code do
    local inst = p.p[3].code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[0]="MOVE",[1]="LOADK",[3]="LOADBOOL",[5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[13]="ADD",[14]="SUB",[30]="JMP",[31]="EQ",[32]="LT",[33]="LE",[34]="TEST",[36]="CALL",[38]="RETURN"}
    print(string.format("  [%d] 0x%08X %s A=%d sbx=%d", i, inst, names[op] or tostring(op), a, sbx))
end

-- 注入 5 个 JMP
junk_jmp.inject(p.p[3], {count = 5, recursive = false})

print("\nAfter inject 5 JMP:")
for i = 1, #p.p[3].code do
    local inst = p.p[3].code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[0]="MOVE",[1]="LOADK",[3]="LOADBOOL",[5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[13]="ADD",[14]="SUB",[30]="JMP",[31]="EQ",[32]="LT",[33]="LE",[34]="TEST",[36]="CALL",[38]="RETURN"}
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
