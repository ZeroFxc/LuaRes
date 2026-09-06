-- const_hide.lua: 常量池隐藏
-- 把多个字符串常量拼接成一个大 blob，运行时用截取函数按偏移还原
-- 常量池中不再出现多个独立字符串，只剩一个大 blob + 数字偏移
-- 用法: const_hide.process(proto)

local luac = require('luac')

local const_hide = {}

local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}

-- 生成截取函数: function(s, i, j) return s:sub(i, j) end
local function make_sub_proto()
    local src = 'return function(s, i, j) return s:sub(i, j) end'
    local proto = luac.undump(string.dec(string.dump(load(src))), false)
    local sp = proto.p[1]
    sp.upvalues[1].instack = 0
    sp.upvalues[1].idx = 0
    return sp
end

-- 收集 proto 中所有字符串常量，返回 {idx0 -> value} 和有序列表
local function collect_strings(proto)
    local strs = {}
    local order = {}
    for i = 1, #proto.k do
        if type(proto.k[i]) == 'string' then
            strs[i - 1] = proto.k[i]
            order[#order + 1] = i - 1
        end
    end
    return strs, order
end

-- 调整跳转: 在 pos 位置插入了 n 条指令
local function adjust_jumps_insert(code, pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            local target = i + sbx + 1
            local delta = 0
            if i < pos and target > pos then
                delta = n
            elseif i >= pos and target < pos then
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

-- 对单个 proto 处理
function const_hide.process_function(proto)
    if not proto.k or #proto.k < 2 then return 0 end

    local strs, order = collect_strings(proto)
    if #order < 2 then return 0 end  -- 少于2个字符串不合并

    -- 1. 构建 blob 和偏移表
    local blob_parts = {}
    local offset_map = {}  -- idx0 -> {offset, endpos}
    local offset = 1
    for _, idx0 in ipairs(order) do
        local s = strs[idx0]
        blob_parts[#blob_parts + 1] = s
        offset_map[idx0] = {offset = offset, endpos = offset + #s - 1}
        offset = offset + #s
    end
    local blob = table.concat(blob_parts)

    -- 2. 添加 blob 常量和 offset/endpos 数字常量
    local blob_idx = #proto.k  -- 0-indexed, 新增位置
    proto.k[#proto.k + 1] = blob

    local num_const_idx = {}  -- idx0 -> {offset_kidx, endpos_kidx}
    for _, idx0 in ipairs(order) do
        local off = offset_map[idx0].offset
        local endp = offset_map[idx0].endpos
        local off_kidx = #proto.k
        proto.k[#proto.k + 1] = off
        local endp_kidx = #proto.k
        proto.k[#proto.k + 1] = endp
        num_const_idx[idx0] = {off = off_kidx, endp = endp_kidx}
    end

    -- 3. 把原字符串常量设为 nil
    for _, idx0 in ipairs(order) do
        proto.k[idx0 + 1] = nil
    end

    -- 4. 添加截取子 proto
    local sub_proto = make_sub_proto()
    local sub_pidx = #proto.p  -- 0-indexed
    proto.p[#proto.p + 1] = sub_proto

    -- 5. 寄存器分配: 用高寄存器，所有截取序列共用
    -- CALL A,B,C 的参数从 A+1 连续排列, 所以 blob 直接放 ARG1(A+1)
    local base_reg = proto.maxstacksize
    local SUB_REG = base_reg
    local ARG1_REG = base_reg + 1  -- blob (参数1)
    local ARG2_REG = base_reg + 2  -- offset (参数2)
    local ARG3_REG = base_reg + 3  -- endpos (参数3)
    local TMP_REG = base_reg + 4   -- GETTABUP/SETTABUP 临时 upvalue 寄存器
    proto.maxstacksize = base_reg + 5

    -- 生成截取序列 (5条指令), 结果在 SUB_REG
    local function make_sub_seq(str_idx0)
        local nc = num_const_idx[str_idx0]
        return {
            luac.CREATE_ABx(1, ARG1_REG, blob_idx),       -- LOADK ARG1, blob (参数1)
            luac.CREATE_ABx(44, SUB_REG, sub_pidx),        -- CLOSURE SUB_REG, sub_proto
            luac.CREATE_ABx(1, ARG2_REG, nc.off),           -- LOADK ARG2, offset
            luac.CREATE_ABx(1, ARG3_REG, nc.endp),          -- LOADK ARG3, endpos
            luac.CREATE_ABC(36, SUB_REG, 4, 2),             -- CALL SUB_REG, 4, 2
        }
    end

    -- 在 pos 位置插入序列，返回插入的指令数
    local function insert_seq(pos, seq)
        for i = #seq, 1, -1 do
            table.insert(proto.code, pos, seq[i])
        end
        adjust_jumps_insert(proto.code, pos, #seq)
        return #seq
    end

    -- 6. 扫描指令，替换引用
    local count = 0
    local i = 1
    while i <= #proto.code do
        local op = luac.GET_OPCODE(proto.code[i])
        local a = luac.GETARG_A(proto.code[i])
        local b = luac.GETARG_B(proto.code[i])
        local c = luac.GETARG_C(proto.code[i])

        if op == 1 then  -- LOADK
            local bx = luac.GETARG_Bx(proto.code[i])
            if offset_map[bx] then
                -- LOADK R_a, K(bx) -> 截取序列 + MOVE R_a, SUB_REG
                local seq = make_sub_seq(bx)
                if a ~= SUB_REG then
                    seq[#seq + 1] = luac.CREATE_ABC(0, a, SUB_REG, 0)  -- MOVE a, SUB_REG
                end
                proto.code[i] = seq[1]
                for j = 2, #seq do
                    table.insert(proto.code, i + j - 1, seq[j])
                end
                adjust_jumps_insert(proto.code, i, #seq - 1)
                count = count + 1
                i = i + #seq
                goto continue
            end

        elseif op == 7 then  -- GETTABLE a, b, c
            if c >= 256 and offset_map[c - 256] then
                local kidx = c - 256
                local seq = make_sub_seq(kidx)
                -- 替换为: 截取序列 + GETTABLE a, b, SUB_REG
                seq[#seq + 1] = luac.CREATE_ABC(7, a, b, SUB_REG)
                proto.code[i] = seq[1]
                for j = 2, #seq do
                    table.insert(proto.code, i + j - 1, seq[j])
                end
                adjust_jumps_insert(proto.code, i, #seq - 1)
                count = count + 1
                i = i + #seq
                goto continue
            end

        elseif op == 10 then  -- SETTABLE a, b, c: R(A)[R(B)] = R(C), B是键
            if b >= 256 and offset_map[b - 256] then
                local kidx = b - 256
                local seq = make_sub_seq(kidx)
                seq[#seq + 1] = luac.CREATE_ABC(10, a, SUB_REG, c)  -- SETTABLE a, key, value
                proto.code[i] = seq[1]
                for j = 2, #seq do
                    table.insert(proto.code, i + j - 1, seq[j])
                end
                adjust_jumps_insert(proto.code, i, #seq - 1)
                count = count + 1
                i = i + #seq
                goto continue
            end

        elseif op == 6 then  -- GETTABUP a, b, c
            if c >= 256 and offset_map[c - 256] then
                local kidx = c - 256
                local seq = make_sub_seq(kidx)
                -- GETTABUP -> GETUPVAL tmp, b + 截取 + GETTABLE a, tmp, SUB_REG
                -- 需要一个额外寄存器放 upvalue 值, 用 BLOB_REG(截取序列用完后可复用)
                local UPVAL_REG = TMP_REG
                local full_seq = {
                    luac.CREATE_ABC(5, UPVAL_REG, b, 0),  -- GETUPVAL UPVAL_REG, b
                }
                for _, ins in ipairs(seq) do
                    full_seq[#full_seq + 1] = ins
                end
                full_seq[#full_seq + 1] = luac.CREATE_ABC(7, a, UPVAL_REG, SUB_REG)
                proto.code[i] = full_seq[1]
                for j = 2, #full_seq do
                    table.insert(proto.code, i + j - 1, full_seq[j])
                end
                adjust_jumps_insert(proto.code, i, #full_seq - 1)
                count = count + 1
                i = i + #full_seq
                goto continue
            end

        elseif op == 8 then  -- SETTABUP a, b, c
            if c >= 256 and offset_map[c - 256] then
                local kidx = c - 256
                local seq = make_sub_seq(kidx)
                local UPVAL_REG = TMP_REG
                local full_seq = {
                    luac.CREATE_ABC(5, UPVAL_REG, b, 0),  -- GETUPVAL UPVAL_REG, b
                }
                for _, ins in ipairs(seq) do
                    full_seq[#full_seq + 1] = ins
                end
                -- SETTABLE UPVAL_REG, SUB_REG, R_a  (注意: SETTABLE a=table, b=key, c=value)
                full_seq[#full_seq + 1] = luac.CREATE_ABC(10, UPVAL_REG, SUB_REG, a)
                proto.code[i] = full_seq[1]
                for j = 2, #full_seq do
                    table.insert(proto.code, i + j - 1, full_seq[j])
                end
                adjust_jumps_insert(proto.code, i, #full_seq - 1)
                count = count + 1
                i = i + #full_seq
                goto continue
            end

        elseif op == 12 then  -- SELF a, b, c
            if c >= 256 and offset_map[c - 256] then
                local kidx = c - 256
                local seq = make_sub_seq(kidx)
                seq[#seq + 1] = luac.CREATE_ABC(12, a, b, SUB_REG)
                proto.code[i] = seq[1]
                for j = 2, #seq do
                    table.insert(proto.code, i + j - 1, seq[j])
                end
                adjust_jumps_insert(proto.code, i, #seq - 1)
                count = count + 1
                i = i + #seq
                goto continue
            end
        end

        i = i + 1
        ::continue::
    end

    return count
end

-- 递归处理整个 proto 树
-- 注意: 先处理子 proto, 再处理当前 proto.
-- 因为当前 proto 处理时会新增截取子 proto, 必须保证它不被递归处理
function const_hide.process(proto)
    local total = 0
    if proto.p then
        for i = 1, #proto.p do
            total = total + const_hide.process(proto.p[i])
        end
    end
    total = total + const_hide.process_function(proto)
    return total
end

return const_hide
