-- debool_obfuscate.lua: 布尔混淆反向
-- 识别 bool_obfuscate 产生的5种模式并还原
-- 用法: debool_obfuscate.clean(proto)

local luac = require('luac')

local debool = {}

local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}

local function collect_protos(proto, list)
    list = list or {}
    list[#list + 1] = proto
    if proto.p then
        for i = 1, #proto.p do
            collect_protos(proto.p[i], list)
        end
    end
    return list
end

local function adjust_jumps_remove(code, remove_pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            local target = i + sbx + 1
            local delta = 0
            if i < remove_pos and target > remove_pos then
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

local function make_loadbool(a, b, c)
    return (3) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23) | ((c & 0x1FF) << 14)
end

local function make_not(a, b)
    return (27) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23)
end

local function make_test(a, c)
    return (34) | ((a & 0xFF) << 6) | ((c & 0x1FF) << 14)
end

-- ============================================================
-- 模式1: LOADBOOL a,1-b,0 + NOT a,a -> LOADBOOL a,b,0
-- ============================================================
local function reverse_loadbool_const(code)
    local count = 0
    local i = 1
    while i <= #code - 1 do
        local op1 = code[i] % 64
        local op2 = code[i + 1] % 64
        if op1 == 3 and op2 == 27 then  -- LOADBOOL + NOT
            local a1 = (code[i] >> 6) & 0xFF
            local b1 = (code[i] >> 23) & 0x1FF
            local c1 = (code[i] >> 14) & 0x1FF
            local a2 = (code[i + 1] >> 6) & 0xFF
            local b2 = (code[i + 1] >> 23) & 0x1FF
            -- NOT a,a 且 LOADBOOL C=0
            if c1 == 0 and a1 == a2 and a2 == b2 then
                -- 还原: LOADBOOL a, 1-b, 0
                code[i] = make_loadbool(a1, 1 - b1, 0)
                table.remove(code, i + 1)
                adjust_jumps_remove(code, i + 1, 1)
                count = count + 1
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
-- 模式2: CMP(1-A) + JMP sBx=1 + LOADBOOL false,skip + LOADBOOL true + NOT a,a
--         -> CMP(A) + JMP + false(skip) + true
-- ============================================================
local function reverse_comparison(code)
    local count = 0
    local i = 1
    while i <= #code - 4 do
        local op1 = code[i] % 64
        if op1 == 31 or op1 == 32 or op1 == 33 then  -- EQ/LT/LE
            local op2 = code[i + 1] % 64
            if op2 == 30 then  -- JMP
                local bx2 = code[i + 1] >> 14
                local sbx2 = bx2 - 131071
                if sbx2 == 1 then
                    local op3 = code[i + 2] % 64
                    local op4 = code[i + 3] % 64
                    local op5 = code[i + 4] % 64
                    if op3 == 3 and op4 == 3 and op5 == 27 then  -- LOADBOOL + LOADBOOL + NOT
                        local a3 = (code[i + 2] >> 6) & 0xFF
                        local b3 = (code[i + 2] >> 23) & 0x1FF
                        local c3 = (code[i + 2] >> 14) & 0x1FF
                        local a4 = (code[i + 3] >> 6) & 0xFF
                        local b4 = (code[i + 3] >> 23) & 0x1FF
                        local c4 = (code[i + 3] >> 14) & 0x1FF
                        local a5 = (code[i + 4] >> 6) & 0xFF
                        local b5 = (code[i + 4] >> 23) & 0x1FF
                        -- 确认模式: false(skip) + true + NOT a,a
                        if b3 == 0 and c3 == 1 and b4 == 1 and c4 == 0 and
                           a3 == a4 and a4 == a5 and a5 == b5 then
                            -- 还原 CMP 的 A 字段: 1-A -> A
                            local a1 = (code[i] >> 6) & 0xFF
                            code[i] = (code[i] & ~(0xFF << 6)) | (((1 - a1) & 0xFF) << 6)
                            -- 删除 NOT
                            table.remove(code, i + 4)
                            adjust_jumps_remove(code, i + 4, 1)
                            count = count + 1
                            i = i + 4
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
-- 模式3: NOT tmp,b + NOT a,tmp -> NOT a,b
-- ============================================================
local function reverse_not_double(code)
    local count = 0
    local i = 1
    while i <= #code - 1 do
        local op1 = code[i] % 64
        local op2 = code[i + 1] % 64
        if op1 == 27 and op2 == 27 then  -- NOT + NOT
            local a1 = (code[i] >> 6) & 0xFF
            local b1 = (code[i] >> 23) & 0x1FF
            local a2 = (code[i + 1] >> 6) & 0xFF
            local b2 = (code[i + 1] >> 23) & 0x1FF
            -- NOT tmp,b + NOT a,tmp
            if b1 < 256 and b2 < 256 and a1 == b2 and a1 ~= a2 and a1 ~= b1 then
                -- 还原: NOT a2, b1
                code[i] = make_not(a2, b1)
                table.remove(code, i + 1)
                adjust_jumps_remove(code, i + 1, 1)
                count = count + 1
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
-- 模式4: NOT tmp,a + TEST tmp,1-c -> TEST a,c
-- ============================================================
local function reverse_test_double(code)
    local count = 0
    local i = 1
    while i <= #code - 1 do
        local op1 = code[i] % 64
        local op2 = code[i + 1] % 64
        if op1 == 27 and op2 == 34 then  -- NOT + TEST
            local a1 = (code[i] >> 6) & 0xFF
            local b1 = (code[i] >> 23) & 0x1FF
            local a2 = (code[i + 1] >> 6) & 0xFF
            local c2 = (code[i + 1] >> 14) & 0x1FF
            -- NOT tmp,a + TEST tmp,1-c
            if b1 < 256 and a1 == a2 and a1 ~= b1 then
                -- 还原: TEST b1, 1-c2
                code[i] = make_test(b1, 1 - c2)
                table.remove(code, i + 1)
                adjust_jumps_remove(code, i + 1, 1)
                count = count + 1
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
-- 模式5: LOADK tmp1,1 + LOADK tmp2,x + EQ A=1 + JMP sBx=1 +
--         LOADBOOL a,false,skip + LOADBOOL a,true
--         -> LOADBOOL a, (x==1?1:0), 0
-- ============================================================
local function reverse_bool_to_number(code, proto)
    local count = 0
    local i = 1
    while i <= #code - 5 do
        local op1 = code[i] % 64
        local op2 = code[i + 1] % 64
        local op3 = code[i + 2] % 64
        local op4 = code[i + 3] % 64
        local op5 = code[i + 4] % 64
        local op6 = code[i + 5] % 64
        if op1 == 1 and op2 == 1 and op3 == 31 and op4 == 30 and op5 == 3 and op6 == 3 then
            local a1 = (code[i] >> 6) & 0xFF
            local bx1 = (code[i] >> 14) & 0x3FFFF
            local a2 = (code[i + 1] >> 6) & 0xFF
            local bx2 = (code[i + 1] >> 14) & 0x3FFFF
            local a3 = (code[i + 2] >> 6) & 0xFF
            local b3 = (code[i + 2] >> 23) & 0x1FF
            local c3 = (code[i + 2] >> 14) & 0x1FF
            local bx4 = code[i + 3] >> 14
            local sbx4 = bx4 - 131071
            local a5 = (code[i + 4] >> 6) & 0xFF
            local b5 = (code[i + 4] >> 23) & 0x1FF
            local c5 = (code[i + 4] >> 14) & 0x1FF
            local a6 = (code[i + 5] >> 6) & 0xFF
            local b6 = (code[i + 5] >> 23) & 0x1FF
            local c6 = (code[i + 5] >> 14) & 0x1FF

            -- 检查模式
            if a3 == 1 and b3 == a1 and c3 == a2 and sbx4 == 1 and
               b5 == 0 and c5 == 1 and b6 == 1 and c6 == 0 and a5 == a6 then
                local v1 = proto.k[bx1 + 1]
                local v2 = proto.k[bx2 + 1]
                if type(v1) == 'number' and v1 == 1 and type(v2) == 'number' then
                    local bool_val = (v2 == 1) and 1 or 0
                    code[i] = make_loadbool(a5, bool_val, 0)
                    for j = 1, 5 do
                        table.remove(code, i + 1)
                    end
                    adjust_jumps_remove(code, i + 1, 5)
                    count = count + 1
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

-- 对单个函数进行布尔混淆反向
function debool.clean_function(proto)
    local code = proto.code
    local total = 0
    -- 按顺序应用各种反向，多次迭代直到没有变化
    local changed = true
    local iter = 0
    while changed and iter < 10 do
        changed = false
        local c1 = reverse_loadbool_const(code)
        local c2 = reverse_comparison(code)
        local c3 = reverse_not_double(code)
        local c4 = reverse_test_double(code)
        local c5 = reverse_bool_to_number(code, proto)
        local sum = c1 + c2 + c3 + c4 + c5
        if sum > 0 then changed = true end
        total = total + sum
        iter = iter + 1
    end
    return total
end

-- 对整个 proto 树进行布尔混淆反向
function debool.clean(proto)
    local all_protos = collect_protos(proto)
    local total = 0
    for _, p in ipairs(all_protos) do
        total = total + debool.clean_function(p)
    end
    return total
end

return debool
