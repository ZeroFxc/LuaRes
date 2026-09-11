-- dejunk_jmp.lua - 去除垃圾 JMP 指令（sBx=0 的 JMP）
-- 识别并移除 JMP sBx=0（跳到下一条指令，纯占位）
--
-- 用法: local dejunk_jmp = require("dejunk_jmp"); dejunk_jmp.remove(proto)

local luac = require("luac")

local dejunk_jmp = {}

local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}

-- 调整跳转偏移（移除指令后）
local function adjust_jumps_remove(code, remove_pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            if op == 30 and sbx == 0 then
                -- skip sBx=0 JMP (will be removed too if in range)
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

-- 去除单个函数中的垃圾 JMP
local function remove_in_func(p)
    local removed = 0
    local i = 1
    while i <= #p.code do
        local inst = p.code[i]
        local op = inst % 64
        if op == 30 then  -- JMP
            local bx = inst >> 14
            local sbx = bx - 131071
            if sbx == 0 then
                -- 垃圾 JMP，移除
                adjust_jumps_remove(p.code, i, 1)
                table.remove(p.code, i)
                removed = removed + 1
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    return removed
end

function dejunk_jmp.remove(proto, options)
    options = options or {}
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    local total = remove_in_func(proto)

    if recursive then
        for i = 1, #proto.p do
            total = total + dejunk_jmp.remove(proto.p[i], options)
        end
    end

    return total
end

-- CLI
if arg and arg[0] and arg[0]:match("dejunk_jmp") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_dejmp.lua")

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    local p = luac.undump(data, false)
    local removed = dejunk_jmp.remove(p)
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Removed " .. removed .. " junk JMP instructions")
    local ok = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return dejunk_jmp
