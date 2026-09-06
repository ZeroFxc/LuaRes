-- deopaque_predicate.lua - 去除 opaque_predicate 注入的不透明谓词死代码
-- 模式（函数开头）:
--   LOADK r1, Kst(0)    -- r1 = maxstacksize
--   LOADK r2, Kst(0)    -- r2 = maxstacksize + 1
--   LT A=0, B=r1, C=r2  -- 0<0 false, A=0 不跳过
--   JMP sBx=dead_len     -- 跳过死代码
--   [dead_len 条随机垃圾]
--   原始代码...
--
-- 用法: local deop = require("deopaque_predicate"); deop.remove(proto)

local luac = require("luac")

local deopaque_predicate = {}

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

-- 检查从 pos 开始的 n 条指令是否是随机垃圾
local function is_junk_block(code, pos, n, num_consts)
    if pos + n - 1 > #code then return false end
    local junk_score = 0
    for i = pos, pos + n - 1 do
        local inst = code[i]
        local op = inst % 64
        local a = (inst >> 6) & 0xFF
        local b = (inst >> 23) & 0x1FF
        local c = (inst >> 14) & 0x1FF

        if a >= 16 then junk_score = junk_score + 1 end
        if b < 256 and b >= 16 then junk_score = junk_score + 1 end
        if c < 256 and c >= 16 then junk_score = junk_score + 1 end
        if op > 46 then junk_score = junk_score + 2 end
        if op == 1 and b >= num_consts then junk_score = junk_score + 2 end
    end
    return junk_score >= n
end

-- 检查函数开头是否是 opaque_predicate 模式
-- 返回 {start, length} 或 nil
local function find_opaque_block(p, start_pos)
    if start_pos + 3 > #p.code then return nil end

    -- 指令1: LOADK r1, Kst(0)
    local i1 = p.code[start_pos]
    local op1 = i1 % 64
    if op1 ~= 1 then return nil end  -- LOADK
    local a1 = (i1 >> 6) & 0xFF
    local bx1 = i1 >> 14
    -- 检查常量是否是 0
    if p.k[bx1 + 1] ~= 0 then return nil end

    -- 指令2: LOADK r2, Kst(0)
    local i2 = p.code[start_pos + 1]
    local op2 = i2 % 64
    if op2 ~= 1 then return nil end
    local a2 = (i2 >> 6) & 0xFF
    local bx2 = i2 >> 14
    if p.k[bx2 + 1] ~= 0 then return nil end
    -- r2 应该是 r1 + 1
    if a2 ~= a1 + 1 then return nil end

    -- 指令3: LT A=0, B=r1, C=r2
    local i3 = p.code[start_pos + 2]
    local op3 = i3 % 64
    if op3 ~= 32 then return nil end  -- LT
    local a3 = (i3 >> 6) & 0xFF
    local b3 = (i3 >> 23) & 0x1FF
    local c3 = (i3 >> 14) & 0x1FF
    if a3 ~= 0 then return nil end
    if b3 ~= a1 then return nil end
    if c3 ~= a2 then return nil end

    -- 指令4: JMP sBx=dead_len
    local i4 = p.code[start_pos + 3]
    local op4 = i4 % 64
    if op4 ~= 30 then return nil end  -- JMP
    local a4 = (i4 >> 6) & 0xFF
    if a4 ~= 0 then return nil end
    local bx4 = i4 >> 14
    local sbx4 = bx4 - 131071
    if sbx4 < 5 or sbx4 > 15 then return nil end  -- dead_len = 5-15

    -- 检查死代码块是否是垃圾
    local junk_start = start_pos + 4
    local junk_len = sbx4
    if not is_junk_block(p.code, junk_start, junk_len, #p.k) then
        return nil
    end

    -- 整个块长度: LOADK+LOADK+LT+JMP+垃圾
    return {start = start_pos, length = 4 + junk_len}
end

local function remove_in_func(p)
    local removed = 0
    -- opaque_predicate 在函数开头注入（也可能在子函数开头）
    local block = find_opaque_block(p, 1)
    if block then
        adjust_jumps_remove(p.code, block.start, block.length)
        for j = 1, block.length do
            table.remove(p.code, block.start)
        end
        removed = removed + block.length
    end
    return removed
end

function deopaque_predicate.remove(proto, options)
    options = options or {}
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    local total = remove_in_func(proto)

    if recursive then
        for i = 1, #proto.p do
            total = total + deopaque_predicate.remove(proto.p[i], options)
        end
    end

    return total
end

-- CLI
if arg and arg[0] and arg[0]:match("deopaque_predicate") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_deop.lua")

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    local p = luac.undump(data, false)
    local removed = deopaque_predicate.remove(p)
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Removed " .. removed .. " instructions from opaque_predicate")
    local ok = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return deopaque_predicate
