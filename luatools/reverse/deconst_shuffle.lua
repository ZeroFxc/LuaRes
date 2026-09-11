-- deconst_shuffle.lua - 常量池排序美化
-- const_shuffle 随机打乱常量池顺序, 无法还原原始顺序
-- 但可以按类型/值排序, 使反编译结果更可读
-- 排序规则: nil < boolean < number < string, 同类型按值排序
--
-- 用法: local desort = require("deconst_shuffle"); desort.sort(proto)

local luac = require("luac")

local deconst_shuffle = {}

local BITRK = 0x100
local OP_LOADK = 1
local OP_LOADKX = 2
local OP_EXTRAARG = 46
local OP_CLOSURE = 44

-- 类型排序权重
local function type_rank(v)
    if v == nil then return 0 end
    local t = type(v)
    if t == "boolean" then return 1 end
    if t == "number" then return 2 end
    if t == "string" then return 3 end
    return 4
end

-- 比较两个常量值
local function const_compare(a, b)
    local ra = type_rank(a)
    local rb = type_rank(b)
    if ra ~= rb then return ra < rb end
    -- 同类型比较
    if ra == 1 then return (a and 1 or 0) < (b and 1 or 0) end
    if ra == 2 then return a < b end
    if ra == 3 then return a < b end
    return false
end

local function sort_function(proto)
    local n = #proto.k
    if n <= 1 then
        for i = 1, #proto.p do sort_function(proto.p[i]) end
        return 0
    end

    -- 创建索引数组并排序
    local indices = {}
    for i = 1, n do indices[i] = i end
    table.sort(indices, function(a, b)
        return const_compare(proto.k[a], proto.k[b])
    end)

    -- 构建旧索引 -> 新索引的映射
    local remap = {}
    local new_k = {}
    for new_idx, old_idx in ipairs(indices) do
        remap[old_idx - 1] = new_idx - 1  -- 0-based
        new_k[new_idx] = proto.k[old_idx]
    end
    proto.k = new_k

    -- 更新所有指令中的常量索引引用
    local code = proto.code
    for i = 1, #code do
        local ins = code[i]
        local op = ins % 64

        if op == OP_LOADK then
            local old_bx = luac.GETARG_Bx(ins)
            if remap[old_bx] then
                code[i] = luac.SETARG_Bx(ins, remap[old_bx])
            end
        elseif op == OP_LOADKX then
            -- LOADKX 的 Bx 未使用, 常量索引在 EXTRAARG 中
            -- 不更新 Bx
        elseif op == OP_EXTRAARG then
            local old_ax = luac.GETARG_Ax(ins)
            if remap[old_ax] then
                code[i] = luac.SETARG_Ax(ins, remap[old_ax])
            end
        elseif op ~= OP_CLOSURE and op ~= 30 and op ~= 39 and op ~= 40 and op ~= 42 then
            -- iABC: 检查 B 和 C
            local b = (ins >> 23) & 0x1FF
            local c = (ins >> 14) & 0x1FF
            local changed = false
            if b >= BITRK then
                local old_idx = b - BITRK
                if remap[old_idx] then
                    b = remap[old_idx] + BITRK
                    changed = true
                end
            end
            if c >= BITRK then
                local old_idx = c - BITRK
                if remap[old_idx] then
                    c = remap[old_idx] + BITRK
                    changed = true
                end
            end
            if changed then
                code[i] = luac.SETARG_B(ins, b)
                code[i] = luac.SETARG_C(code[i], c)
            end
        end
    end

    -- 递归子函数
    for i = 1, #proto.p do
        sort_function(proto.p[i])
    end

    return n
end

function deconst_shuffle.sort(proto, options)
    options = options or {}
    return sort_function(proto)
end

-- CLI
if arg and arg[0] and arg[0]:match("deconst_shuffle") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_desort.lua")

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    local p = luac.undump(data, false)
    local sorted = deconst_shuffle.sort(p)
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Sorted " .. sorted .. " constants")
    local ok = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return deconst_shuffle
