local luac = require("luac")
local junk_jmp = require("junk_jmp")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

-- mul 是 p[2]，注入 count=25
junk_jmp.inject(p.p[2], {count = 25, recursive = false})

print("mul after 25 JMP (first 20 instructions):")
for i = 1, math.min(20, #p.p[2].code) do
    local inst = p.p[2].code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[0]="MOVE",[1]="LOADK",[5]="GETUPVAL",[30]="JMP",[36]="CALL",[38]="RETURN",[39]="FORLOOP",[40]="FORPREP"}
    local target = ""
    if op == 30 or op == 39 or op == 40 then
        target = string.format(" ->%d", i + sbx + 1)
    end
    print(string.format("  [%2d] 0x%08X %-8s A=%d sbx=%d%s", i, inst, names[op] or tostring(op), a, sbx, target))
end

-- 找 FORPREP 和 FORLOOP
print("\nFORPREP/FORLOOP positions:")
for i = 1, #p.p[2].code do
    local op = p.p[2].code[i] % 64
    if op == 40 or op == 39 then
        local bx = p.p[2].code[i] >> 14
        local sbx = bx - 131071
        print(string.format("  [%d] %s sbx=%d ->%d", i, op==40 and "FORPREP" or "FORLOOP", sbx, i+sbx+1))
    end
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
