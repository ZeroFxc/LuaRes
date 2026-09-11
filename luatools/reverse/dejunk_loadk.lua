-- dejunk_loadk.lua - 去除垃圾 LOADK 指令
-- 识别并移除加载到高寄存器且后续未使用的 LOADK
--
-- 用法: local dejunk_loadk = require("dejunk_loadk"); dejunk_loadk.remove(proto)

local luac = require("luac")

local dejunk_loadk = {}

local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}

local function adjust_jumps_remove(code, remove_pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            if op == 30 and sbx == 0 then
                -- skip
            else
                local target = i + sbx + 1
                local delta = 0
                if i < remove_pos and target >= remove_pos then
                    delta = -n
                elseif i >= remove_pos and target < remove_pos then
                    delta = n
                end
                if delta ~= 0 then
                    local new_sbx = sbx + delta
                    local new_bx = new_sbx + 131071
                    code[i] = (code[i] & 0x3FFF) | (new_bx << 14)
                end
            end
        end
    end
end

-- 检查寄存器是否在后续指令中被读取
local function reg_used_after(code, start_pos, reg)
    for i = start_pos, #code do
        local inst = code[i]
        local op = inst % 64
        local a = (inst >> 6) & 0xFF
        local b = (inst >> 23) & 0x1FF
        local c = (inst >> 14) & 0x1FF

        -- 跳转指令：停止分析（控制流改变）
        if JUMP_OPS[op] or op == 38 then  -- RETURN
            break
        end

        -- 检查 B/C 是否读取该寄存器
        if op ~= 1 and op ~= 3 and op ~= 4 then  -- 不是纯定义指令
            if b < 256 and b == reg then return true end
            if c < 256 and c == reg then return true end
        end

        -- 如果该寄存器被重新定义，停止（后续使用是新值）
        if a == reg and op ~= 0 then  -- MOVE 不算重新定义（可能是传递）
            break
        end
    end
    return false
end

local function remove_in_func(p)
    local removed = 0
    local threshold = p.maxstacksize - 5  -- 高寄存器阈值
    if threshold < 5 then threshold = 5 end

    local i = 1
    while i <= #p.code do
        local inst = p.code[i]
        local op = inst % 64
        if op == 1 then  -- LOADK
            local a = (inst >> 6) & 0xFF
            local bx = inst >> 14
            -- 垃圾 LOADK: 目标是高寄存器，加载数字常量，
            -- 且下一条指令是 LOADK 到同一寄存器（立即覆盖，之前的值肯定未使用）
            if a >= threshold and i + 1 <= #p.code then
                local const = p.k[bx + 1]
                local next_inst = p.code[i + 1]
                local next_op = next_inst % 64
                local next_a = (next_inst >> 6) & 0xFF
                if type(const) == "number" and next_op == 1 and next_a == a then
                    -- 下一条 LOADK 覆盖同一寄存器，当前 LOADK 是垃圾
                    adjust_jumps_remove(p.code, i, 1)
                    table.remove(p.code, i)
                    removed = removed + 1
                else
                    i = i + 1
                end
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    return removed
end

function dejunk_loadk.remove(proto, options)
    options = options or {}
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    local total = remove_in_func(proto)

    if recursive then
        for i = 1, #proto.p do
            total = total + dejunk_loadk.remove(proto.p[i], options)
        end
    end

    return total
end

-- CLI
if arg and arg[0] and arg[0]:match("dejunk_loadk") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_deloadk.lua")

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    local p = luac.undump(data, false)
    local removed = dejunk_loadk.remove(p)
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Removed " .. removed .. " junk LOADK instructions")
    local ok = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return dejunk_loadk
