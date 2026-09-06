local luac = require("luac")

local f = io.open("E:/LuaRes/main(1)_clean2.lua", "rb")
local data = f:read("*a")
f:close()

local p = luac.undump(data, false)

-- 找一个有 GETTABUP+SETLIST 模式的函数
local function find_pattern(proto, depth)
    local code = proto.code
    local gettabup_count = 0
    local setlist_count = 0
    for i = 1, #code do
        local op = code[i] % 64
        if op == 6 then gettabup_count = gettabup_count + 1 end
        if op == 45 then setlist_count = setlist_count + 1 end
    end
    if gettabup_count >= 5 and setlist_count >= 1 then
        print(string.format("Found at depth %d: GETTABUP=%d, SETLIST=%d, code=%d",
            depth, gettabup_count, setlist_count, #code))
        -- 打印前 60 条指令
        for i = 1, math.min(60, #code) do
            local inst = code[i]
            local op = inst % 64
            local a = (inst >> 6) & 0xFF
            local b = (inst >> 23) & 0x1FF
            local c = (inst >> 14) & 0x1FF
            local names = {[0]="MOVE",[1]="LOADK",[5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[44]="SETLIST",[45]="SETLIST",[38]="RETURN"}
            print(string.format("  [%3d] 0x%08X %-8s A=%d B=%d C=%d", i, inst, names[op] or tostring(op), a, b, c))
        end
        return true
    end
    for i = 1, #proto.p do
        if find_pattern(proto.p[i], depth + 1) then return true end
    end
    return false
end

find_pattern(p, 0)
