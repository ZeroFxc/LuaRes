-- table_obfuscate.lua - 表指令混淆模块
--
-- 混淆技术:
--   1. NEWTABLE 分配提示清零: NEWTABLE A B C -> NEWTABLE A 0 0
--      (B/C 仅是数组/哈希容量预分配提示, 清零不改变语义)
--   2. SELF 展开: SELF A B C -> MOVE A+1 B + GETTABLE A B C
--   3. GETTABLE 常量键物化: GETTABLE A B K(key) -> LOADK tmp K(key) + GETTABLE A B R(tmp)
--   4. SETTABLE 常量键物化: SETTABLE A K(key) C -> LOADK tmp K(key) + SETTABLE A R(tmp) C
--   5. SETTABLE 常量值物化: SETTABLE A B K(val) -> LOADK tmp K(val) + SETTABLE A B R(val)
--   6. GETTABUP/SETTABUP 常量键值物化 (同上, 针对 upvalue 表)
--
-- 用法: local to = require("table_obfuscate"); to.obfuscate(proto, {rate=0.5})

local luac = require("luac")

local table_obfuscate = {}

local BITRK = 0x100
local JUMP_OPS = { [30] = true, [39] = true, [40] = true, [42] = true }

-- 跳转偏移调整 (插入 n 条指令于 insert_pos 之前)
local function adjust_jumps_insert(code, insert_pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            if not (op == 30 and sbx == 0) then
                local target = i + sbx + 1
                local delta = 0
                if i < insert_pos and target >= insert_pos then
                    delta = n
                elseif i >= insert_pos and target < insert_pos then
                    delta = -n
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

-- 指令构造 (位运算, 与 luac.CREATE_* 等价但更快)
local function make_move(a, b)
    return (0) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23)
end
local function make_loadk(a, bx)
    return (1) | ((a & 0xFF) << 6) | ((bx & 0x3FFFF) << 14)
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
local function make_newtable(a, b, c)
    return (11) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23) | ((c & 0x1FF) << 14)
end

-- ============================================================
-- 技术1: NEWTABLE 分配提示清零
-- ============================================================
local function obfuscate_newtable(proto, options)
    local code = proto.code
    local count = 0
    local rate = options.newtable_rate or 0.8
    for i = 1, #code do
        local op = code[i] % 64
        if op == 11 then  -- NEWTABLE
            local b = (code[i] >> 23) & 0x1FF
            local c = (code[i] >> 14) & 0x1FF
            if (b > 0 or c > 0) and math.random() < rate then
                local a = (code[i] >> 6) & 0xFF
                code[i] = make_newtable(a, 0, 0)
                count = count + 1
            end
        end
    end
    return count
end

-- ============================================================
-- 技术2: SELF 展开为 MOVE + GETTABLE
-- ============================================================
local function obfuscate_self(proto, options)
    local code = proto.code
    local count = 0
    local rate = options.self_rate or 0.5
    local i = 1
    while i <= #code do
        local op = code[i] % 64
        if op == 12 then  -- SELF
            if math.random() < rate then
                local a = (code[i] >> 6) & 0xFF
                local b = (code[i] >> 23) & 0x1FF
                local c = (code[i] >> 14) & 0x1FF
                -- SELF A B C -> MOVE A+1 B + GETTABLE A B C
                code[i] = make_move(a + 1, b)
                table.insert(code, i + 1, make_gettable(a, b, c))
                adjust_jumps_insert(code, i + 1, 1)
                count = count + 1
                i = i + 2
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
-- 技术3-7: 常量键/值物化
-- 共用: 找一个高位临时寄存器
-- ============================================================
local function get_temp_reg(proto)
    -- 使用 maxstacksize 作为临时寄存器 (原代码未使用), 调用方负责 bump
    return proto.maxstacksize
end

-- GETTABLE A B K(key) -> LOADK tmp K(key) + GETTABLE A B R(tmp)
local function obfuscate_gettable_key(proto, options, tmp_reg)
    local code = proto.code
    local count = 0
    local rate = options.gettable_key_rate or 0.4
    local i = 1
    while i <= #code do
        local op = code[i] % 64
        if op == 7 then  -- GETTABLE
            local a = (code[i] >> 6) & 0xFF
            local b = (code[i] >> 23) & 0x1FF
            local c = (code[i] >> 14) & 0x1FF
            -- C 是常量引用且目标寄存器 A 不等于临时寄存器
            if c >= BITRK and a ~= tmp_reg and b < 256 and math.random() < rate then
                local key_idx = c - BITRK
                code[i] = make_loadk(tmp_reg, key_idx)
                table.insert(code, i + 1, make_gettable(a, b, tmp_reg))
                adjust_jumps_insert(code, i + 1, 1)
                count = count + 1
                i = i + 2
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    return count
end

-- SETTABLE A K(key) C -> LOADK tmp K(key) + SETTABLE A R(tmp) C
local function obfuscate_settable_key(proto, options, tmp_reg)
    local code = proto.code
    local count = 0
    local rate = options.settable_key_rate or 0.4
    local i = 1
    while i <= #code do
        local op = code[i] % 64
        if op == 10 then  -- SETTABLE
            local a = (code[i] >> 6) & 0xFF
            local b = (code[i] >> 23) & 0x1FF
            local c = (code[i] >> 14) & 0x1FF
            if b >= BITRK and a ~= tmp_reg and math.random() < rate then
                local key_idx = b - BITRK
                code[i] = make_loadk(tmp_reg, key_idx)
                table.insert(code, i + 1, make_settable(a, tmp_reg, c))
                adjust_jumps_insert(code, i + 1, 1)
                count = count + 1
                i = i + 2
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    return count
end

-- SETTABLE A B K(val) -> LOADK tmp K(val) + SETTABLE A B R(tmp)
local function obfuscate_settable_val(proto, options, tmp_reg)
    local code = proto.code
    local count = 0
    local rate = options.settable_val_rate or 0.3
    local i = 1
    while i <= #code do
        local op = code[i] % 64
        if op == 10 then  -- SETTABLE
            local a = (code[i] >> 6) & 0xFF
            local b = (code[i] >> 23) & 0x1FF
            local c = (code[i] >> 14) & 0x1FF
            -- C 是常量引用, 且 B 不是临时寄存器(避免和键物化冲突)
            if c >= BITRK and b ~= tmp_reg and a ~= tmp_reg and math.random() < rate then
                local val_idx = c - BITRK
                code[i] = make_loadk(tmp_reg, val_idx)
                table.insert(code, i + 1, make_settable(a, b, tmp_reg))
                adjust_jumps_insert(code, i + 1, 1)
                count = count + 1
                i = i + 2
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    return count
end

-- GETTABUP A B K(key) -> LOADK tmp K(key) + GETTABUP A B R(tmp)
local function obfuscate_gettabup_key(proto, options, tmp_reg)
    local code = proto.code
    local count = 0
    local rate = options.gettabup_key_rate or 0.4
    local i = 1
    while i <= #code do
        local op = code[i] % 64
        if op == 6 then  -- GETTABUP
            local a = (code[i] >> 6) & 0xFF
            local b = (code[i] >> 23) & 0x1FF
            local c = (code[i] >> 14) & 0x1FF
            if c >= BITRK and a ~= tmp_reg and math.random() < rate then
                local key_idx = c - BITRK
                code[i] = make_loadk(tmp_reg, key_idx)
                table.insert(code, i + 1, make_gettabup(a, b, tmp_reg))
                adjust_jumps_insert(code, i + 1, 1)
                count = count + 1
                i = i + 2
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    return count
end

-- SETTABUP A K(key) C -> LOADK tmp K(key) + SETTABUP A R(tmp) C
-- SETTABUP A B K(val) -> LOADK tmp K(val) + SETTABUP A B R(tmp)
local function obfuscate_settabup(proto, options, tmp_reg)
    local code = proto.code
    local count = 0
    local rate = options.settabup_rate or 0.35
    local i = 1
    while i <= #code do
        local op = code[i] % 64
        if op == 8 then  -- SETTABUP
            local a = (code[i] >> 6) & 0xFF
            local b = (code[i] >> 23) & 0x1FF
            local c = (code[i] >> 14) & 0x1FF
            local materialize_key = (b >= BITRK)
            local materialize_val = (c >= BITRK and not materialize_key)
            -- 键和值都是常量时随机选一个物化
            if b >= BITRK and c >= BITRK then
                if math.random() < 0.5 then
                    materialize_key = true
                    materialize_val = false
                else
                    materialize_key = false
                    materialize_val = true
                end
            end
            if (materialize_key or materialize_val) and math.random() < rate then
                if materialize_key then
                    local key_idx = b - BITRK
                    code[i] = make_loadk(tmp_reg, key_idx)
                    table.insert(code, i + 1, make_settabup(a, tmp_reg, c))
                else
                    local val_idx = c - BITRK
                    code[i] = make_loadk(tmp_reg, val_idx)
                    table.insert(code, i + 1, make_settabup(a, b, tmp_reg))
                end
                adjust_jumps_insert(code, i + 1, 1)
                count = count + 1
                i = i + 2
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
-- 主函数: 对单个 proto 进行表指令混淆
-- ============================================================
function table_obfuscate.obfuscate_proto(proto, options)
    options = options or {}
    local total = 0

    -- 1. NEWTABLE 提示清零 (不插入指令, 先做)
    total = total + obfuscate_newtable(proto, options)

    -- 2. SELF 展开
    total = total + obfuscate_self(proto, options)

    -- 3-7. 常量物化 (共用一个高位临时寄存器)
    local tmp_reg = get_temp_reg(proto)
    local mat_count = 0
    mat_count = mat_count + obfuscate_gettable_key(proto, options, tmp_reg)
    mat_count = mat_count + obfuscate_settable_key(proto, options, tmp_reg)
    mat_count = mat_count + obfuscate_settable_val(proto, options, tmp_reg)
    mat_count = mat_count + obfuscate_gettabup_key(proto, options, tmp_reg)
    mat_count = mat_count + obfuscate_settabup(proto, options, tmp_reg)

    if mat_count > 0 then
        -- 临时寄存器需要在栈帧范围内
        proto.maxstacksize = math.min(math.max(proto.maxstacksize, tmp_reg + 1), 250)
    end
    total = total + mat_count

    return total
end

-- ============================================================
-- 递归处理所有子函数
-- ============================================================
function table_obfuscate.obfuscate(proto, options)
    options = options or {}
    local total = table_obfuscate.obfuscate_proto(proto, options)
    for i = 1, #proto.p do
        total = total + table_obfuscate.obfuscate(proto.p[i], options)
    end
    return total
end

return table_obfuscate
