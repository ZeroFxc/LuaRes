-- deinstruction_mutate.lua - 去除 instruction_mutate 注入的恒等指令
-- instruction_mutate 两种变异:
--   1. 交换操作数 (ADD/MUL/EQ/AND/OR/XOR 的 B,C 交换) — 无法还原, 但语义相同
--   2. 插入恒等指令 ADD A,A,Kst(0) (在数值运算后, 25% 概率) — 可识别和移除
--
-- 用法: local demut = require("deinstruction_mutate"); demut.remove(proto)

local luac = require("luac")

local deinstruction_mutate = {}

local BITRK = 0x100
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

local function remove_in_func(p)
    local removed = 0
    local i = 1
    while i <= #p.code do
        local inst = p.code[i]
        local op = inst % 64

        -- 识别 ADD A,A,Kst(0): op=13, B=A, C=BITRK+zero_idx
        if op == 13 then  -- ADD
            local a = (inst >> 6) & 0xFF
            local b = (inst >> 23) & 0x1FF
            local c = (inst >> 14) & 0x1FF
            -- B 必须等于 A (寄存器引用, < 256)
            -- C 必须是常量引用 (>= BITRK), 且常量值为 0
            if b == a and b < 256 and c >= BITRK then
                local const_idx = c - BITRK
                if const_idx < #p.k and p.k[const_idx + 1] == 0 then
                    -- 确认是恒等指令, 移除
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

function deinstruction_mutate.remove(proto, options)
    options = options or {}
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    local total = remove_in_func(proto)

    if recursive then
        for i = 1, #proto.p do
            total = total + deinstruction_mutate.remove(proto.p[i], options)
        end
    end

    return total
end

-- CLI
if arg and arg[0] and arg[0]:match("deinstruction_mutate") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_demut.lua")

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    local p = luac.undump(data, false)
    local removed = deinstruction_mutate.remove(p)
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Removed " .. removed .. " identity ADD instructions")
    local ok = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return deinstruction_mutate
