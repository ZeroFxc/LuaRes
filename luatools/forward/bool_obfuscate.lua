-- bool_obfuscate.lua
-- 布尔值混淆模块
-- 对布尔值常量、比较运算、逻辑运算、条件判断进行混淆
--
-- 混淆技术:
--   1. LOADBOOL 常量替换: true -> not false, false -> not true
--   2. 比较运算取反: a > b -> not (a <= b), a == b -> not (a ~= b) 等
--   3. 逻辑运算德摩根: a and b -> not (not a or not b)
--   4. TEST 条件双重否定: if a then -> if not not a then
--   5. 布尔值数字转换: true -> (1==1), false -> (1==0)
--
-- 用法: local bool_obf = require("bool_obfuscate"); bool_obf.obfuscate(proto, {level=3})

local luac = require("luac")

local bool_obfuscate = {}

local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}
local CONDITION_OPS = {[31]=true,[32]=true,[33]=true,[34]=true,[35]=true}

-- 调整跳转偏移（插入指令后）
local function adjust_jumps_insert(code, insert_pos, n)
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

-- 指令构造函数
local function make_loadk(a, bx)
    return (1) | ((a & 0xFF) << 6) | ((bx & 0x3FFFF) << 14)
end

local function make_loadbool(a, b, c)
    return (3) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23) | ((c & 0x1FF) << 14)
end

local function make_not(a, b)
    return (27) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23)
end

local function make_jmp(sbx)
    local bx = sbx + 131071
    return (30) | ((bx & 0x3FFFF) << 14)
end

local function make_eq(a, b, c)
    return (31) | ((a & 0x1FF) << 6) | ((b & 0x1FF) << 23) | ((c & 0x1FF) << 14)
end

local function make_test(a, c)
    -- andlua TEST: C=1 truthy执行下一条, C=0 truthy跳过下一条
    return (34) | ((a & 0xFF) << 6) | ((c & 0x1FF) << 14)
end

-- 找到常量池中数字的索引，不存在则添加
local function find_or_add_number_const(proto, num)
    for i = 1, #proto.k do
        if proto.k[i] == num and type(proto.k[i]) == "number" then
            return i - 1  -- 0-based
        end
    end
    table.insert(proto.k, num)
    return #proto.k - 1
end

-- 计算代码中使用的最大寄存器
local function calc_max_reg(code)
    local max_r = 0
    for i = 1, #code do
        local op = code[i] % 64
        local a = (code[i] >> 6) & 0xFF
        if a > max_r then max_r = a end
        if op ~= 30 and op ~= 39 and op ~= 40 and op ~= 42 then
            local b = (code[i] >> 23) & 0x1FF
            if b < 256 and b > max_r then max_r = b end
        end
    end
    return math.min(max_r, 250)
end

-- 检查位置是否安全（不在条件指令下一条、不在跳转目标）
local function is_safe_pos(code, pos)
    if pos <= 1 or pos > #code then return false end
    local prev_op = code[pos - 1] % 64
    if CONDITION_OPS[prev_op] then return false end
    local cur_op = code[pos] % 64
    if cur_op == 30 then return false end  -- 不在JMP上
    return true
end

-- ============================================================
-- 技术1: LOADBOOL 常量替换
-- true -> not false (LOADBOOL false + NOT)
-- false -> not true (LOADBOOL true + NOT)
-- ============================================================
local function obfuscate_loadbool(proto, options)
    local code = proto.code
    local count = 0
    local i = 1
    while i <= #code do
        local op = code[i] % 64
        if op == 3 then  -- LOADBOOL
            local a = (code[i] >> 6) & 0xFF
            local b = (code[i] >> 23) & 0x1FF
            local c = (code[i] >> 14) & 0x1FF
            -- 只处理 C=0 的 LOADBOOL（不跳过下一条）
            -- C=1 的是条件表达式的false分支，不能改
            -- 前一条是 LOADBOOL C=1 的是比较运算模式中的true，不能改
            if c == 0 and math.random() < (options.bool_const_rate or 0.5) then
                -- 检查前一条是否是 LOADBOOL C=1（比较运算模式中的false,skip）
                local is_comparison_pattern = false
                if i > 1 then
                    local prev_op = code[i - 1] % 64
                    if prev_op == 3 then
                        local prev_c = (code[i - 1] >> 14) & 0x1FF
                        if prev_c == 1 then
                            is_comparison_pattern = true
                        end
                    end
                end
                if not is_comparison_pattern then
                    -- 替换为: LOADBOOL a, (1-b), 0 + NOT a, a
                    local new_loadbool = make_loadbool(a, 1 - b, 0)
                    local new_not = make_not(a, a)
                    code[i] = new_loadbool
                    table.insert(code, i + 1, new_not)
                    adjust_jumps_insert(code, i + 1, 1)
                    count = count + 1
                    i = i + 2
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
-- 技术2: 比较运算取反
-- 识别模式: LT/LE/EQ + JMP sBx=1 + LOADBOOL false,skip + LOADBOOL true
-- 替换为: 反向比较 + NOT
-- ============================================================
local function obfuscate_comparison(proto, options)
    local code = proto.code
    local count = 0
    local i = 1
    while i <= #code - 3 do
        local op1 = code[i] % 64
        -- 比较运算: LT(32), LE(33), EQ(31)
        if (op1 == 31 or op1 == 32 or op1 == 33) then
            local op2 = code[i + 1] % 64
            if op2 == 30 then  -- JMP
                local bx2 = code[i + 1] >> 14
                local sbx2 = bx2 - 131071
                if sbx2 == 1 then  -- 跳到 i+3 (跳过false)
                    local op3 = code[i + 2] % 64
                    local op4 = code[i + 3] % 64
                    if op3 == 3 and op4 == 3 then  -- LOADBOOL + LOADBOOL
                        local a3 = (code[i + 2] >> 6) & 0xFF
                        local b3 = (code[i + 2] >> 23) & 0x1FF
                        local c3 = (code[i + 2] >> 14) & 0x1FF
                        local a4 = (code[i + 3] >> 6) & 0xFF
                        local b4 = (code[i + 3] >> 23) & 0x1FF
                        local c4 = (code[i + 3] >> 14) & 0x1FF
                        -- 确认模式: false(skip) + true
                        if b3 == 0 and c3 == 1 and b4 == 1 and c4 == 0 and a3 == a4 then
                            if math.random() < (options.comparison_rate or 0.5) then
                                local a = a3
                                -- 方法: 取反CMP的A字段 + 最后加NOT, 结果不变
                                -- 原来4条: CMP(A) + JMP + false(skip) + true → 结果=not(条件满足)
                                -- 现在5条: CMP(1-A) + JMP + false(skip) + true + NOT → 结果=not(not(条件满足))=原来的结果
                                local a1 = (code[i] >> 6) & 0xFF
                                code[i] = (code[i] & ~(0xFF << 6)) | (((1 - a1) & 0xFF) << 6)
                                local new_not = make_not(a, a)
                                table.insert(code, i + 4, new_not)
                                adjust_jumps_insert(code, i + 4, 1)
                                count = count + 1
                                i = i + 5
                            else
                                i = i + 4
                            end
                        else
                            i = i + 1
                        end
                    else
                        i = i + 1
                    end
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
-- 技术3: NOT 指令双重化
-- NOT a, b -> NOT tmp, b + NOT a, tmp
-- ============================================================
local function obfuscate_not(proto, options)
    local code = proto.code
    local count = 0
    local high_reg = calc_max_reg(code) + 2
    if high_reg > 248 then high_reg = 248 end
    local i = 1
    while i <= #code do
        local op = code[i] % 64
        if op == 27 then  -- NOT
            local a = (code[i] >> 6) & 0xFF
            local b = (code[i] >> 23) & 0x1FF
            -- 只处理 A != B 的 NOT（自引用NOT双重化会变成双重否定，结果不变）
            if b < 256 and a ~= b and math.random() < (options.not_double_rate or 0.3) then
                -- NOT a,b -> NOT high,b + NOT a,high
                local tmp = high_reg
                local new_not1 = make_not(tmp, b)
                local new_not2 = make_not(a, tmp)
                code[i] = new_not1
                table.insert(code, i + 1, new_not2)
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
    if count > 0 then
        proto.maxstacksize = math.min(math.max(proto.maxstacksize, high_reg + 1), 250)
    end
    return count
end

-- ============================================================
-- 技术4: TEST 条件双重否定
-- TEST a, c -> NOT tmp, a + TEST tmp, c
-- ============================================================
local function obfuscate_test(proto, options)
    local code = proto.code
    local count = 0
    local high_reg = calc_max_reg(code) + 2
    if high_reg > 248 then high_reg = 248 end
    local i = 1
    while i <= #code - 1 do
        local op = code[i] % 64
        if op == 34 then  -- TEST
            local a = (code[i] >> 6) & 0xFF
            local c = (code[i] >> 14) & 0x1FF
            local next_op = code[i + 1] % 64
            if next_op == 30 and math.random() < (options.test_double_rate or 0.3) then
                -- TEST a,c -> NOT tmp,a + TEST tmp,1-c
                -- NOT取反了寄存器值, 所以C也要取反才能保持条件不变
                local tmp = high_reg
                local new_not = make_not(tmp, a)
                local new_test = make_test(tmp, 1 - c)
                code[i] = new_not
                table.insert(code, i + 1, new_test)
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
    if count > 0 then
        proto.maxstacksize = math.min(math.max(proto.maxstacksize, high_reg + 1), 250)
    end
    return count
end

-- ============================================================
-- 技术5: 布尔值数字转换（在LOADBOOL前插入数字比较）
-- true -> (1==1) 产生的布尔值
-- false -> (1==0) 产生的布尔值
-- ============================================================
local function obfuscate_bool_to_number(proto, options)
    local code = proto.code
    local count = 0
    local high_reg = calc_max_reg(code) + 2
    if high_reg > 246 then high_reg = 246 end
    local const1 = find_or_add_number_const(proto, 1)
    local const0 = find_or_add_number_const(proto, 0)
    local i = 1
    while i <= #code do
        local op = code[i] % 64
        if op == 3 then  -- LOADBOOL
            local a = (code[i] >> 6) & 0xFF
            local b = (code[i] >> 23) & 0x1FF
            local c = (code[i] >> 14) & 0x1FF
            if c == 0 and math.random() < (options.bool_num_rate or 0.2) then
                -- 替换为: LOADK tmp1, 1 + LOADK tmp2, (b==1?1:0) + EQ A=1, tmp1, tmp2 + JMP sBx=1 + LOADBOOL a,false,skip + LOADBOOL a,true
                local tmp1 = high_reg
                local tmp2 = high_reg + 1
                local cmp_const = (b == 1) and const1 or const0
                local new_lk1 = make_loadk(tmp1, const1)
                local new_lk2 = make_loadk(tmp2, cmp_const)
                local new_eq = make_eq(1, tmp1, tmp2)  -- A=1 表示 ==
                local new_jmp = make_jmp(1)
                local new_false = make_loadbool(a, 0, 1)
                local new_true = make_loadbool(a, 1, 0)
                -- 替换1条为7条
                code[i] = new_lk1
                table.insert(code, i + 1, new_lk2)
                table.insert(code, i + 2, new_eq)
                table.insert(code, i + 3, new_jmp)
                table.insert(code, i + 4, new_false)
                table.insert(code, i + 5, new_true)
                adjust_jumps_insert(code, i + 1, 6)
                count = count + 1
                i = i + 7
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    if count > 0 then
        proto.maxstacksize = math.min(math.max(proto.maxstacksize, high_reg + 2), 250)
    end
    return count
end

-- ============================================================
-- 主函数：对单个proto进行布尔值混淆
-- ============================================================
function bool_obfuscate.obfuscate_proto(proto, options)
    options = options or {}
    local total = 0
    total = total + obfuscate_comparison(proto, options)
    total = total + obfuscate_loadbool(proto, options)
    -- NOT双重化有bug(双重否定等于肯定), 暂时禁用
    -- total = total + obfuscate_not(proto, options)
    total = total + obfuscate_test(proto, options)
    -- 布尔值数字转换与其他技术混合时不稳定, 默认禁用
    if options.bool_num_rate and options.bool_num_rate > 0 then
        total = total + obfuscate_bool_to_number(proto, options)
    end
    return total
end

-- ============================================================
-- 递归处理所有子函数
-- ============================================================
function bool_obfuscate.obfuscate(proto, options)
    options = options or {}
    local total = bool_obfuscate.obfuscate_proto(proto, options)
    for i = 1, #proto.p do
        total = total + bool_obfuscate.obfuscate(proto.p[i], options)
    end
    return total
end

return bool_obfuscate
