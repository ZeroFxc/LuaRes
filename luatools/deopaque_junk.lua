-- deopaque_junk.lua - 去除不透明谓词垃圾分支
-- 识别模式: LOADK R(high),k[0] + TEST R(high),C=1 + JMP sBx=N + [垃圾 N 条]
--
-- 用法: local deopaque_junk = require("deopaque_junk"); deopaque_junk.remove(proto)

local luac = require("luac")

local deopaque_junk = {}

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

-- 检查是否是不透明谓词垃圾分支
-- 返回 {start, length} 或 nil
local function find_opaque_branch(code, k, pos, maxstack)
    if pos + 2 > #code then return nil end

    local inst1 = code[pos]
    local op1 = inst1 % 64
    if op1 ~= 1 then return nil end  -- 必须是 LOADK

    local a1 = (inst1 >> 6) & 0xFF
    local bx1 = inst1 >> 14

    local inst2 = code[pos + 1]
    local op2 = inst2 % 64
    if op2 ~= 34 then return nil end  -- 必须是 TEST

    local a2 = (inst2 >> 6) & 0xFF
    local c2 = (inst2 >> 14) & 0x1FF
    if a2 ~= a1 then return nil end  -- TEST 的 A 必须和 LOADK 的 A 相同
    if c2 ~= 1 then return nil end  -- TEST 的 C 必须是 1 (andlua 语义)

    local inst3 = code[pos + 2]
    local op3 = inst3 % 64
    if op3 ~= 30 then return nil end  -- 必须是 JMP

    local a3 = (inst3 >> 6) & 0xFF
    if a3 ~= 0 then return nil end  -- JMP 的 A 必须是 0 (不关闭 upvalue)

    local bx3 = inst3 >> 14
    local sbx3 = bx3 - 131071
    if sbx3 < 1 or sbx3 > 50 then return nil end  -- 垃圾分支大小 1-50

    -- 检查 JMP 的目标是否正确（跳过 sbx 条垃圾指令）
    local target = pos + 2 + sbx3 + 1  -- 1-based
    if target > #code + 1 then return nil end

    -- 检查 LOADK 的目标寄存器是否是高寄存器
    if a1 < maxstack - 10 then return nil end

    -- 检查 LOADK 加载的常量是否是字符串（k[0] 通常是函数名）
    local const = k[bx1 + 1]
    if type(const) ~= "string" then return nil end

    -- 检查垃圾指令是否都使用高寄存器
    for j = pos + 3, pos + 2 + sbx3 do
        if j > #code then return nil end
        local junk = code[j]
        local junk_op = junk % 64
        local junk_a = (junk >> 6) & 0xFF
        -- 垃圾指令的目标寄存器应该是高寄存器
        if junk_a < maxstack - 10 and junk_op ~= 0 and junk_op ~= 27 then
            return nil
        end
    end

    return {start = pos, length = 2 + sbx3 + 1}  -- LOADK+TEST+JMP+垃圾
end

local function remove_in_func(p)
    local removed = 0
    local i = 1
    while i <= #p.code do
        local branch = find_opaque_branch(p.code, p.k, i, p.maxstacksize)
        if branch then
            adjust_jumps_remove(p.code, branch.start, branch.length)
            for j = 1, branch.length do
                table.remove(p.code, branch.start)
            end
            removed = removed + branch.length
        else
            i = i + 1
        end
    end
    return removed
end

function deopaque_junk.remove(proto, options)
    options = options or {}
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    local total = remove_in_func(proto)

    if recursive then
        for i = 1, #proto.p do
            total = total + deopaque_junk.remove(proto.p[i], options)
        end
    end

    return total
end

-- CLI
if arg and arg[0] and arg[0]:match("deopaque_junk") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_deopj.lua")

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    local p = luac.undump(data, false)
    local removed = deopaque_junk.remove(p)
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Removed " .. removed .. " instructions from opaque junk branches")
    local ok = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return deopaque_junk
