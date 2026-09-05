local luac = require("luac")
local junk_jmp = require("junk_jmp")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

junk_jmp.inject(p.p[3], {count = 10, recursive = false})

print("fib after 10 JMP:")
for i = 1, #p.p[3].code do
    local inst = p.p[3].code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[0]="MOVE",[1]="LOADK",[3]="LOADBOOL",[5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[13]="ADD",[14]="SUB",[30]="JMP",[31]="EQ",[32]="LT",[33]="LE",[34]="TEST",[36]="CALL",[37]="TAILCALL",[38]="RETURN"}
    local target = ""
    if op == 30 or op == 31 or op == 32 or op == 33 or op == 34 then
        target = string.format(" ->%d", i + sbx + 1)
    end
    print(string.format("  [%2d] 0x%08X %-8s A=%d sbx=%d%s", i, inst, names[op] or tostring(op), a, sbx, target))
end
