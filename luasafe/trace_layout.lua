local luac = require("luac")

local f = io.open("E:/LuaRes/layout_clean.lua", "rb")
local data = f:read("*a")
f:close()

local p = luac.undump(data, false)

-- 找出 main 函数中所有 JMP、CALL、RETURN 的位置
print("Main function key instructions:")
print("  code count: " .. #p.code)
for i = 1, #p.code do
    local inst = p.code[i]
    local op = inst % 64
    if op == 29 or op == 35 or op == 37 or op == 36 then  -- JMP, CALL, RETURN, TAILCALL
        local a = (inst >> 6) & 0xFF
        local b = (inst >> 23) & 0x1FF
        local c = (inst >> 14) & 0x1FF
        local bx = inst >> 14
        local sbx = bx - 131071
        local names = {[29]="JMP",[35]="CALL",[36]="TAILCALL",[37]="RETURN"}
        local extra = ""
        if op == 29 then extra = string.format(" sbx=%d ->%d", sbx, i+sbx+1) end
        print(string.format("  [%5d] 0x%08X %-8s A=%d B=%d C=%d%s", i, inst, names[op], a, b, c, extra))
    end
end

-- 分析前 200 条指令的执行路径
print("\nExecution path trace (first 200 instructions):")
local pc = 1
local visited = {}
local steps = 0
while pc >= 1 and pc <= #p.code and steps < 200 and not visited[pc] do
    visited[pc] = true
    steps = steps + 1
    local inst = p.code[pc]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local b = (inst >> 23) & 0x1FF
    local c = (inst >> 14) & 0x1FF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[0]="MOVE",[1]="LOADK",[5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[8]="SETTABUP",[9]="SETTABLE",[10]="NEWTABLE",[12]="ADD",[13]="SUB",[14]="MUL",[28]="CONCAT",[29]="JMP",[30]="EQ",[31]="LT",[32]="LE",[33]="TEST",[34]="TESTSET",[35]="CALL",[36]="TAILCALL",[37]="RETURN",[38]="FORLOOP",[39]="FORPREP",[40]="TFORCALL",[41]="TFORLOOP",[42]="SETLIST",[43]="CLOSURE",[44]="VARARG"}
    local name = names[op] or ("OP_" .. op)

    local next_pc = pc + 1
    local note = ""
    if op == 29 then  -- JMP
        next_pc = pc + sbx + 1
        note = string.format(" -> jump to %d", next_pc)
    elseif op == 30 or op == 31 or op == 32 then  -- EQ/LT/LE
        note = " conditional (pc++ if true)"
    elseif op == 33 or op == 34 then  -- TEST/TESTSET
        note = " conditional (pc++ if true)"
    elseif op == 37 then  -- RETURN
        note = " RETURN"
        next_pc = -1
    end

    print(string.format("  [%3d] pc=%5d 0x%08X %-10s A=%d B=%d C=%d%s",
        steps, pc, inst, name, a, b, c, note))

    if next_pc == -1 then break end
    pc = next_pc
end

print("\nTrace stopped at pc=" .. tostring(pc) .. ", steps=" .. steps)
