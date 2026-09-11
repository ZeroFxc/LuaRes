-- detable_obfuscate.lua - 还原 table_obfuscate 注入的表指令混淆
--
-- 还原技术:
--   1. MOVE A+1 B + GETTABLE A B C -> SELF A B C
--   2. LOADK tmp K(key) + GETTABLE A B R(tmp) -> GETTABLE A B K(key)
--   3. LOADK tmp K(key) + SETTABLE A R(tmp) C -> SETTABLE A K(key) C
--   4. LOADK tmp K(val) + SETTABLE A B R(val) -> SETTABLE A B K(val)
--   5. LOADK tmp K(key) + GETTABUP A B R(tmp) -> GETTABUP A B K(key)
--   6. LOADK tmp K(key) + SETTABUP A R(tmp) C -> SETTABUP A K(key) C
--   7. LOADK tmp K(val) + SETTABUP A B R(val) -> SETTABUP A B K(val)
--
-- NEWTABLE 提示清零是有损的 (原提示无法恢复), 但不影响语义, 无需还原.
--
-- 用法: local dto = require("detable_obfuscate"); dto.clean(proto)

local luac = require("luac")

local detable_obfuscate = {}

local BITRK = 0x100
local JUMP_OPS = { [30] = true, [39] = true, [40] = true, [42] = true }

-- 跳转偏移调整 (删除 n 条指令于 remove_pos)
local function adjust_jumps_remove(code, remove_pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            if not (op == 30 and sbx == 0) then
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

-- 指令构造
local function make_self(a, b, c)
    return (12) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23) | ((c & 0x1FF) << 14)
end
local function make_gettable(a, b, c)
    return (7) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23) | ((c & 0x1FF) << 14)
end
local function make_settable(a, b, c)
    return (10) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23) | ((c & 0x1FF) << 14)
end
local function make_gettabup(a, b, c)
    return (6) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23) | ((c & 0x1FF) << 14)
end
local function make_settabup(a, b, c)
    return (8) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23) | ((c & 0x1FF) << 14)
end

-- 检查寄存器 reg 在 code[start..#code] 中是否在被写入前被读取
-- 用于判断 LOADK 的目标寄存器是否为临时寄存器 (物化后不再存活)
local function is_reg_live_after(code, start, reg)
    for i = start, #code do
        local op = code[i] % 64
        local a = (code[i] >> 6) & 0xFF
        -- 写寄存器的指令: A 是目标
        -- MOVE(0), LOADK(1), LOADKX(2), LOADBOOL(3), LOADNIL(4),
        -- GETUPVAL(5), GETTABUP(6), GETTABLE(7), SETTABUP(8)不写A, SETTABLE(10)不写A,
        -- NEWTABLE(11), SELF(12), 算术运算(13-29), TESTSET(35), CALL(36)写A..,
        -- VARARG(46), CONCAT(29)
        local writes_a = true  -- 大部分指令 A 是目标
        if op == 8 or op == 10 or op == 30 or op == 31 or op == 32 or op == 33
            or op == 34 or op == 36 or op == 37 or op == 38 or op == 44
            or op == 43 or op == 45 then
            writes_a = false
        end
        -- 检查 B/C 是否读取 reg
        local b = (code[i] >> 23) & 0x1FF
        local c = (code[i] >> 14) & 0x1FF
        local reads_b = true
        local reads_c = true
        -- 某些指令 B/C 不是寄存器引用
        if op == 1 or op == 2 or op == 3 or op == 4 or op == 11
            or op == 30 or op == 39 or op == 40 or op == 42 or op == 44
            or op == 43 or op == 46 then
            reads_b = false
            reads_c = false
        end
        if op == 36 or op == 37 or op == 38 then
            -- CALL/TAILCALL/RETURN: B/C 是参数计数, 不是寄存器
            reads_b = false
            reads_c = false
        end
        if reads_b and b < 256 and b == reg then return true end
        if reads_c and c < 256 and c == reg then return true end
        -- CALL 指令会读取 A 开始的多个寄存器作为参数
        if (op == 36 or op == 37) and a <= reg and reg < a + ((code[i] >> 23) & 0x1FF) then
            return true
        end
        if writes_a and a == reg then
            -- 被写入了, 之后的存活与本次 LOADK 无关
            return false
        end
    end
    return false
end

-- ============================================================
-- 技术1: MOVE A+1 B + GETTABLE A B C -> SELF A B C
-- ============================================================
local function restore_self(proto)
    local code = proto.code
    local count = 0
    local i = 1
    while i <= #code - 1 do
        local op1 = code[i] % 64
        if op1 == 0 then  -- MOVE
            local a1 = (code[i] >> 6) & 0xFF
            local b1 = (code[i] >> 23) & 0x1FF
            local op2 = code[i + 1] % 64
            if op2 == 7 then  -- GETTABLE
                local a2 = (code[i + 1] >> 6) & 0xFF
                local b2 = (code[i + 1] >> 23) & 0x1FF
                local c2 = (code[i + 1] >> 14) & 0x1FF
                -- MOVE A+1 B + GETTABLE A B C -> SELF A B C
                if a1 == a2 + 1 and b1 == b2 and b1 < 256 then
                    code[i] = make_self(a2, b2, c2)
                    adjust_jumps_remove(code, i + 1, 1)
                    table.remove(code, i + 1)
                    count = count + 1
                    -- 不跳 i, 继续检查当前位置 (可能有连续模式)
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
    return count
end

-- ============================================================
-- 技术2-7: LOADK tmp K(x) + TABLE_OP R(tmp) -> TABLE_OP K(x)
-- ============================================================
local function restore_materialized(proto)
    local code = proto.code
    local count = 0
    local i = 1
    while i <= #code - 1 do
        local op1 = code[i] % 64
        if op1 == 1 then  -- LOADK
            local tmp = (code[i] >> 6) & 0xFF
            local key_idx = (code[i] >> 14) & 0x3FFFF
            local op2 = code[i + 1] % 64
            local reversed = false

            if op2 == 7 then  -- GETTABLE A B C
                local a = (code[i + 1] >> 6) & 0xFF
                local b = (code[i + 1] >> 23) & 0x1FF
                local c = (code[i + 1] >> 14) & 0x1FF
                -- C 是寄存器引用且等于 tmp
                if c == tmp and c < 256 and a ~= tmp
                    and not is_reg_live_after(code, i + 2, tmp) then
                    code[i] = make_gettable(a, b, key_idx + BITRK)
                    adjust_jumps_remove(code, i + 1, 1)
                    table.remove(code, i + 1)
                    count = count + 1
                    reversed = true
                end
            elseif op2 == 10 then  -- SETTABLE A B C
                local a = (code[i + 1] >> 6) & 0xFF
                local b = (code[i + 1] >> 23) & 0x1FF
                local c = (code[i + 1] >> 14) & 0x1FF
                if b == tmp and b < 256 and a ~= tmp
                    and not is_reg_live_after(code, i + 2, tmp) then
                    -- 键物化: SETTABLE A R(tmp) C -> SETTABLE A K(key) C
                    code[i] = make_settable(a, key_idx + BITRK, c)
                    adjust_jumps_remove(code, i + 1, 1)
                    table.remove(code, i + 1)
                    count = count + 1
                    reversed = true
                elseif c == tmp and c < 256 and a ~= tmp and b ~= tmp
                    and not is_reg_live_after(code, i + 2, tmp) then
                    -- 值物化: SETTABLE A B R(tmp) -> SETTABLE A B K(val)
                    code[i] = make_settable(a, b, key_idx + BITRK)
                    adjust_jumps_remove(code, i + 1, 1)
                    table.remove(code, i + 1)
                    count = count + 1
                    reversed = true
                end
            elseif op2 == 6 then  -- GETTABUP A B C
                local a = (code[i + 1] >> 6) & 0xFF
                local b = (code[i + 1] >> 23) & 0x1FF
                local c = (code[i + 1] >> 14) & 0x1FF
                if c == tmp and c < 256 and a ~= tmp
                    and not is_reg_live_after(code, i + 2, tmp) then
                    code[i] = make_gettabup(a, b, key_idx + BITRK)
                    adjust_jumps_remove(code, i + 1, 1)
                    table.remove(code, i + 1)
                    count = count + 1
                    reversed = true
                end
            elseif op2 == 8 then  -- SETTABUP A B C
                local a = (code[i + 1] >> 6) & 0xFF
                local b = (code[i + 1] >> 23) & 0x1FF
                local c = (code[i + 1] >> 14) & 0x1FF
                if b == tmp and b < 256
                    and not is_reg_live_after(code, i + 2, tmp) then
                    code[i] = make_settabup(a, key_idx + BITRK, c)
                    adjust_jumps_remove(code, i + 1, 1)
                    table.remove(code, i + 1)
                    count = count + 1
                    reversed = true
                elseif c == tmp and c < 256 and b ~= tmp
                    and not is_reg_live_after(code, i + 2, tmp) then
                    code[i] = make_settabup(a, b, key_idx + BITRK)
                    adjust_jumps_remove(code, i + 1, 1)
                    table.remove(code, i + 1)
                    count = count + 1
                    reversed = true
                end
            end

            if reversed then
                -- 不跳 i, 继续检查当前位置
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    return count
end

-- ============================================================
-- 主函数
-- ============================================================
function detable_obfuscate.clean_proto(proto, options)
    options = options or {}
    local total = 0
    -- 先还原 SELF (MOVE+GETTABLE), 再还原常量物化
    total = total + restore_self(proto)
    total = total + restore_materialized(proto)
    return total
end

function detable_obfuscate.clean(proto, options)
    options = options or {}
    local total = detable_obfuscate.clean_proto(proto, options)
    for i = 1, #proto.p do
        total = total + detable_obfuscate.clean(proto.p[i], options)
    end
    return total
end

return detable_obfuscate
