-- 纯指令级别字符串混淆：分割乱序 + CONCAT 拼接
-- 不使用 string.char/string.byte 等任何 C 函数
-- 解密过程只用 LOADK / GETTABLE / CONCAT / 算术指令
local luac = require('luac')

local str_split = {}

-- 把字符串分成 n 段
local function split_string(s, n)
    local parts = {}
    local len = #s
    if len < n then n = math.max(2, math.floor(len / 2)) end
    local seg = math.floor(len / n)
    local pos = 1
    for i = 1, n do
        local this_seg = seg
        if i == n then this_seg = len - pos + 1 end
        if this_seg < 1 then this_seg = 1 end
        parts[i] = s:sub(pos, pos + this_seg - 1)
        pos = pos + this_seg
        if pos > len then break end
    end
    -- 补齐到 n 段
    while #parts < n do
        parts[#parts + 1] = ""
    end
    return parts
end

-- 生成随机置换（Fisher-Yates）
local function random_perm(n)
    local perm = {}
    for i = 1, n do perm[i] = i end
    for i = n, 2, -1 do
        local j = math.random(1, i)
        perm[i], perm[j] = perm[j], perm[i]
    end
    return perm
end

-- 根据字符串长度决定段数
local function choose_segments(len)
    if len <= 2 then return 2 end
    if len <= 5 then return 3 end
    return 4
end

-- 收集 proto 中所有引用字符串常量的指令位置和类型
local function collect_string_refs(proto)
    local refs = {}
    local string_set = {}
    for i = 1, #proto.code do
        local inst = proto.code[i]
        local op = luac.GET_OPCODE(inst)
        if op == luac.OP_LOADK then
            local bx = luac.GETARG_Bx(inst)
            if type(proto.k[bx + 1]) == "string" then
                refs[#refs + 1] = {pos = i, op = op, kind = "loadk", idx = bx}
                string_set[bx] = true
            end
        elseif op == luac.OP_GETTABUP then
            local c = luac.GETARG_C(inst)
            if c >= 256 then
                local idx = c - 256
                if type(proto.k[idx + 1]) == "string" then
                    refs[#refs + 1] = {pos = i, op = op, kind = "gettabup", idx = idx}
                    string_set[idx] = true
                end
            end
        elseif op == luac.OP_GETTABLE then
            local c = luac.GETARG_C(inst)
            if c >= 256 then
                local idx = c - 256
                if type(proto.k[idx + 1]) == "string" then
                    refs[#refs + 1] = {pos = i, op = op, kind = "gettable", idx = idx}
                    string_set[idx] = true
                end
            end
        elseif op == luac.OP_SETTABUP then
            local c = luac.GETARG_C(inst)
            if c >= 256 then
                local idx = c - 256
                if type(proto.k[idx + 1]) == "string" then
                    refs[#refs + 1] = {pos = i, op = op, kind = "settabup", idx = idx}
                    string_set[idx] = true
                end
            end
        elseif op == luac.OP_SETTABLE then
            local c = luac.GETARG_C(inst)
            if c >= 256 then
                local idx = c - 256
                if type(proto.k[idx + 1]) == "string" then
                    refs[#refs + 1] = {pos = i, op = op, kind = "settable", idx = idx}
                    string_set[idx] = true
                end
            end
        elseif op == luac.OP_SELF then
            local c = luac.GETARG_C(inst)
            if c >= 256 then
                local idx = c - 256
                if type(proto.k[idx + 1]) == "string" then
                    refs[#refs + 1] = {pos = i, op = op, kind = "self", idx = idx}
                    string_set[idx] = true
                end
            end
        end
    end
    return refs, string_set
end

-- 计算 proto 中最大寄存器
local function calc_max_reg(proto)
    local max_r = proto.maxstacksize - 1
    for i = 1, #proto.code do
        local inst = proto.code[i]
        local op = luac.GET_OPCODE(inst)
        local a = luac.GETARG_A(inst)
        if a > max_r then max_r = a end
        if op <= 46 then
            local b = luac.GETARG_B(inst)
            local c = luac.GETARG_C(inst)
            if b < 255 and b > max_r then max_r = b end
            if c < 255 and c > max_r then max_r = c end
        end
    end
    return max_r
end

-- 对单个函数进行字符串分割混淆
function str_split.obfuscate_function(proto, options)
    options = options or {}
    local min_len = options.min_len or 2

    local refs, string_set = collect_string_refs(proto)
    if #refs == 0 then return 0 end

    -- 为每个字符串常量生成分段，并添加到常量池末尾
    -- seg_map[orig_idx] = {seg_indices = {正确顺序的常量索引}, n = 段数}
    local seg_map = {}
    for idx in pairs(string_set) do
        local s = proto.k[idx + 1]
        if os.getenv("STR_SPLIT_DEBUG") then
            io.stderr:write(string.format("[str_split] idx=%d s='%s' len=%d\n", idx, tostring(s), #s))
        end
        if #s >= min_len then
            local n = choose_segments(#s)
            local parts = split_string(s, n)
            if os.getenv("STR_SPLIT_DEBUG") then
                io.stderr:write(string.format("  n=%d parts={%s}\n", n, table.concat(parts, "|")))
            end
            local perm = random_perm(n)
            local correct_indices = {}
            local base0 = #proto.k
            for i = 1, n do
                local pos = perm[i]
                local lua_idx = base0 + pos
                proto.k[lua_idx] = parts[i]
                correct_indices[i] = base0 + pos - 1
            end
            seg_map[idx] = {indices = correct_indices, n = n}
        end
    end

    if not next(seg_map) then return 0 end

    -- 把原始字符串常量替换为等长垃圾字符串（防止直接从常量池读取明文）
    for idx in pairs(seg_map) do
        local s = proto.k[idx + 1]
        local len = #s
        local junk = {}
        for j = 1, len do
            junk[j] = string.char(math.random(33, 126))
        end
        proto.k[idx + 1] = table.concat(junk)
    end

    local max_reg = calc_max_reg(proto)
    local tmp_base = math.min(max_reg + 5, 240)  -- 临时寄存器起始

    -- 构建新指令序列
    local new_code = {}
    for i = 1, #proto.code do
        local inst = proto.code[i]
        local op = luac.GET_OPCODE(inst)
        local handled = false

        if op == luac.OP_LOADK then
            local bx = luac.GETARG_Bx(inst)
            if seg_map[bx] then
                local a = luac.GETARG_A(inst)
                local seg = seg_map[bx]
                local key_reg = tmp_base
                -- 按正确顺序加载段到临时寄存器（不覆盖目标寄存器后续的寄存器）
                for j = 1, seg.n do
                    table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg + j - 1, seg.indices[j]))
                end
                -- CONCAT 拼接
                if seg.n >= 2 then
                    table.insert(new_code, luac.CREATE_ABC(luac.OP_CONCAT, key_reg, key_reg, key_reg + seg.n - 1))
                end
                -- MOVE 回目标寄存器
                table.insert(new_code, luac.CREATE_ABC(luac.OP_MOVE, a, key_reg, 0))
                handled = true
            end
        elseif op == luac.OP_GETTABUP then
            local a = luac.GETARG_A(inst)
            local b = luac.GETARG_B(inst)
            local c = luac.GETARG_C(inst)
            if c >= 256 then
                local idx = c - 256
                if seg_map[idx] then
                    local seg = seg_map[idx]
                    local key_reg = tmp_base
                    local table_reg = tmp_base + seg.n
                    -- GETUPVAL table_reg, b
                    table.insert(new_code, luac.CREATE_ABC(luac.OP_GETUPVAL, table_reg, b, 0))
                    -- 加载段到连续寄存器
                    for j = 1, seg.n do
                        table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg + j - 1, seg.indices[j]))
                    end
                    -- CONCAT 拼接 key
                    if seg.n >= 2 then
                        table.insert(new_code, luac.CREATE_ABC(luac.OP_CONCAT, key_reg, key_reg, key_reg + seg.n - 1))
                    end
                    -- GETTABLE a, table_reg, key_reg
                    table.insert(new_code, luac.CREATE_ABC(luac.OP_GETTABLE, a, table_reg, key_reg))
                    handled = true
                end
            end
        elseif op == luac.OP_GETTABLE then
            local a = luac.GETARG_A(inst)
            local b = luac.GETARG_B(inst)
            local c = luac.GETARG_C(inst)
            if c >= 256 then
                local idx = c - 256
                if seg_map[idx] then
                    local seg = seg_map[idx]
                    local key_reg = tmp_base
                    -- 加载段
                    for j = 1, seg.n do
                        table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg + j - 1, seg.indices[j]))
                    end
                    if seg.n >= 2 then
                        table.insert(new_code, luac.CREATE_ABC(luac.OP_CONCAT, key_reg, key_reg, key_reg + seg.n - 1))
                    end
                    table.insert(new_code, luac.CREATE_ABC(luac.OP_GETTABLE, a, b, key_reg))
                    handled = true
                end
            end
        elseif op == luac.OP_SETTABUP then
            local a = luac.GETARG_A(inst)
            local b = luac.GETARG_B(inst)
            local c = luac.GETARG_C(inst)
            if c >= 256 then
                local idx = c - 256
                if seg_map[idx] then
                    local seg = seg_map[idx]
                    local key_reg = tmp_base
                    local table_reg = tmp_base + seg.n
                    local val_reg = tmp_base + seg.n + 1
                    -- MOVE val_reg, a （保存要设置的值）
                    table.insert(new_code, luac.CREATE_ABC(luac.OP_MOVE, val_reg, a, 0))
                    -- GETUPVAL table_reg, b
                    table.insert(new_code, luac.CREATE_ABC(luac.OP_GETUPVAL, table_reg, b, 0))
                    -- 加载段
                    for j = 1, seg.n do
                        table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg + j - 1, seg.indices[j]))
                    end
                    if seg.n >= 2 then
                        table.insert(new_code, luac.CREATE_ABC(luac.OP_CONCAT, key_reg, key_reg, key_reg + seg.n - 1))
                    end
                    -- SETTABLE table_reg, key_reg, val_reg
                    table.insert(new_code, luac.CREATE_ABC(luac.OP_SETTABLE, table_reg, key_reg, val_reg))
                    handled = true
                end
            end
        elseif op == luac.OP_SETTABLE then
            local a = luac.GETARG_A(inst)
            local b = luac.GETARG_B(inst)
            local c = luac.GETARG_C(inst)
            if c >= 256 then
                local idx = c - 256
                if seg_map[idx] then
                    local seg = seg_map[idx]
                    local key_reg = tmp_base
                    local val_reg = tmp_base + seg.n
                    -- MOVE val_reg, a
                    table.insert(new_code, luac.CREATE_ABC(luac.OP_MOVE, val_reg, a, 0))
                    -- 加载段
                    for j = 1, seg.n do
                        table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg + j - 1, seg.indices[j]))
                    end
                    if seg.n >= 2 then
                        table.insert(new_code, luac.CREATE_ABC(luac.OP_CONCAT, key_reg, key_reg, key_reg + seg.n - 1))
                    end
                    table.insert(new_code, luac.CREATE_ABC(luac.OP_SETTABLE, b, key_reg, val_reg))
                    handled = true
                end
            end
        elseif op == luac.OP_SELF then
            local a = luac.GETARG_A(inst)
            local b = luac.GETARG_B(inst)
            local c = luac.GETARG_C(inst)
            if c >= 256 then
                local idx = c - 256
                if seg_map[idx] then
                    local seg = seg_map[idx]
                    local key_reg = tmp_base
                    -- SELF 等价: R(a+1)=R(b); R(a)=R(b)[key]
                    -- MOVE a+1, b
                    table.insert(new_code, luac.CREATE_ABC(luac.OP_MOVE, a + 1, b, 0))
                    -- 加载段
                    for j = 1, seg.n do
                        table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, key_reg + j - 1, seg.indices[j]))
                    end
                    if seg.n >= 2 then
                        table.insert(new_code, luac.CREATE_ABC(luac.OP_CONCAT, key_reg, key_reg, key_reg + seg.n - 1))
                    end
                    table.insert(new_code, luac.CREATE_ABC(luac.OP_GETTABLE, a, b, key_reg))
                    handled = true
                end
            end
        end

        if not handled then
            table.insert(new_code, inst)
        end
    end

    proto.code = new_code

    -- 同步 lineinfo
    if proto.lineinfo then
        local new_lineinfo = {}
        for i = 1, #new_code do
            new_lineinfo[i] = proto.lineinfo[i] or 0
        end
        proto.lineinfo = new_lineinfo
    end

    -- 更新 maxstacksize
    proto.maxstacksize = math.min(math.max(proto.maxstacksize, tmp_base + 6), 250)

    return #refs
end

-- 递归处理所有子函数
function str_split.obfuscate(proto, options)
    options = options or {}
    local count = 0
    count = count + str_split.obfuscate_function(proto, options)
    for i = 1, #proto.p do
        count = count + str_split.obfuscate(proto.p[i], options)
    end
    return count
end

return str_split
