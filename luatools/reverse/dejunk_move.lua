-- dejunk_move.lua - 去除垃圾 MOVE 指令
-- 识别并移除高寄存器间且后续未使用的 MOVE
--
-- 用法: local dejunk_move = require("dejunk_move"); dejunk_move.remove(proto)

local luac = require("luac")

local dejunk_move = {}

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

local function reg_used_after(code, start_pos, reg)
    for i = start_pos, #code do
        local inst = code[i]
        local op = inst % 64
        local a = (inst >> 6) & 0xFF
        local b = (inst >> 23) & 0x1FF
        local c = (inst >> 14) & 0x1FF

        if JUMP_OPS[op] or op == 38 then
            break
        end

        if b < 256 and b == reg then return true end
        if c < 256 and c == reg then return true end

        if a == reg and op ~= 0 then
            break
        end
    end
    return false
end

local function remove_in_func(p)
    local removed = 0
    local threshold = p.maxstacksize - 5
    if threshold < 5 then threshold = 5 end

    local i = 1
    while i <= #p.code do
        local inst = p.code[i]
        local op = inst % 64
        if op == 0 then  -- MOVE
            local a = (inst >> 6) & 0xFF
            local b = (inst >> 23) & 0x1FF
            -- 垃圾 MOVE: 源和目标都是高寄存器，
            -- 且下一条指令写入同一目标寄存器（立即覆盖，之前的值肯定未使用）
            if a >= threshold and b >= threshold and i + 1 <= #p.code then
                local next_inst = p.code[i + 1]
                local next_op = next_inst % 64
                local next_a = (next_inst >> 6) & 0xFF
                -- 下一条指令写入同一寄存器（A 字段是目标寄存器）
                -- 排除 JMP（A 字段不是目标寄存器）和条件指令（下一条必须是 JMP）
                if next_a == a and next_op ~= 30 and next_op ~= 31 and next_op ~= 32
                   and next_op ~= 33 and next_op ~= 34 and next_op ~= 35 then
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

function dejunk_move.remove(proto, options)
    options = options or {}
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    local total = remove_in_func(proto)

    if recursive then
        for i = 1, #proto.p do
            total = total + dejunk_move.remove(proto.p[i], options)
        end
    end

    return total
end

-- CLI
if arg and arg[0] and arg[0]:match("dejunk_move") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_demove.lua")

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    local p = luac.undump(data, false)
    local removed = dejunk_move.remove(p)
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Removed " .. removed .. " junk MOVE instructions")
    local ok = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return dejunk_move
