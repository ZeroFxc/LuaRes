local luac = require("luac")

local f = io.open("E:/LuaRes/main(1)_clean2.lua", "rb")
local data = f:read("*a")
f:close()

local p = luac.undump(data, false)

local found = 0
local function find_setlist(proto, path)
    if found >= 3 then return end
    for i = 1, #proto.code do
        local op = proto.code[i] % 64
        if op == 44 or op == 45 then  -- SETLIST
            found = found + 1
            print(string.format("\n=== Found SETLIST at %s [%d] ===", path, i))
            print("maxstack: " .. proto.maxstacksize .. ", code: " .. #proto.code)
            -- 打印前后 30 条指令
            local start = math.max(1, i - 25)
            local endp = math.min(#proto.code, i + 5)
            for j = start, endp do
                local inst = proto.code[j]
                local op2 = inst % 64
                local a = (inst >> 6) & 0xFF
                local b = (inst >> 23) & 0x1FF
                local c = (inst >> 14) & 0x1FF
                local names = {[0]="MOVE",[1]="LOADK",[5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[44]="SETLIST",[45]="SETLIST",[38]="RETURN",[30]="JMP"}
                local marker = (j == i) and " <--" or ""
                print(string.format("  [%3d] 0x%08X %-8s A=%d B=%d C=%d%s", j, inst, names[op2] or tostring(op2), a, b, c, marker))
            end
            break
        end
    end
    for i = 1, #proto.p do
        find_setlist(proto.p[i], path .. "/" .. i)
    end
end

find_setlist(p, "main")
print("\nTotal found: " .. found)
