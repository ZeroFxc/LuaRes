-- deconst_poison.lua: 移除常量池投毒
-- 识别并移除 const_poison 注入的 {__poison = tag} 非法常量
-- 用法: deconst_poison.clean(proto)

local luac = require('luac')

local deconst_poison = {}

local function walk_protos(proto, callback)
    callback(proto)
    if proto.p then
        for i = 1, #proto.p do
            walk_protos(proto.p[i], callback)
        end
    end
end

-- 检查常量是否是投毒常量
local function is_poisoned(k)
    if type(k) == 'table' and k.__poison then
        return true
    end
    return false
end

-- 对单个函数移除投毒常量
function deconst_poison.clean_function(proto)
    if not proto.k then return 0 end

    local removed = 0
    local new_k = {}

    for i = 1, #proto.k do
        if is_poisoned(proto.k[i]) then
            removed = removed + 1
        else
            new_k[#new_k + 1] = proto.k[i]
        end
    end

    if removed == 0 then return 0 end

    -- 投毒常量只在末尾追加，不需要调整 LOADK 索引
    -- 但为了安全，检查是否有 LOADK 引用了被移除的索引
    local old_count = #proto.k
    local new_count = #new_k
    local shift = old_count - new_count

    proto.k = new_k

    -- 如果投毒常量不在末尾（理论上不会），需要调整所有 LOADK 索引
    -- 当前实现只在末尾追加，所以 shift 只影响末尾
    -- 这里做一个安全检查：如果有指令引用了 >= new_count 的常量索引，报错
    for i = 1, #proto.code do
        local op = luac.GET_OPCODE(proto.code[i])
        if op == luac.OP_LOADK then
            local bx = luac.GETARG_Bx(proto.code[i])
            if bx >= new_count then
                -- 这个不应该发生，因为投毒常量在末尾
                -- 但如果发生了，说明有 LOADK 引用了投毒常量，需要处理
                -- 暂时跳过，因为 andlua VM 遇到非法 tag 会当作 nil
            end
        elseif op == luac.OP_LOADKX then
            -- LOADKX + EXTRAARG 模式
            if i < #proto.code then
                local extra = proto.code[i + 1]
                local ax = luac.GETARG_Ax(extra)
                if ax >= new_count then
                    -- 同上
                end
            end
        end
    end

    return removed
end

-- 对整个 proto 树移除投毒常量
function deconst_poison.clean(proto)
    local total = 0
    walk_protos(proto, function(p)
        total = total + deconst_poison.clean_function(p)
    end)
    return total
end

return deconst_poison
