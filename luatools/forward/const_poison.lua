-- const_poison.lua: 常量池投毒
-- 在常量池中注入非法 tag，andlua VM 遇到非法 tag 不读数据（当作 nil）
-- 反编译器可能崩溃或显示异常
-- 用法: const_poison.poison(proto, {count=10, min_tag=0x80, max_tag=0xFF})

local const_poison = {}

-- 递归遍历所有函数
local function walk_protos(proto, callback)
    callback(proto)
    if proto.p then
        for i = 1, #proto.p do
            walk_protos(proto.p[i], callback)
        end
    end
end

-- 对单个函数的常量池投毒
function const_poison.poison_function(proto, options)
    options = options or {}
    local count = options.count or 5
    local min_tag = options.min_tag or 0x80
    local max_tag = options.max_tag or 0xFF

    if not proto.k then return 0 end

    local original_count = #proto.k
    local poisoned = 0

    for i = 1, count do
        local tag = math.random(min_tag, max_tag)
        proto.k[#proto.k + 1] = {__poison = tag}
        poisoned = poisoned + 1
    end

    return poisoned
end

-- 对整个 proto 树的常量池投毒
function const_poison.poison(proto, options)
    options = options or {}
    local total = 0

    walk_protos(proto, function(p)
        total = total + const_poison.poison_function(p, options)
    end)

    return total
end

-- 只对 main 函数投毒（子函数不投毒，更安全）
function const_poison.poison_main(proto, options)
    return const_poison.poison_function(proto, options)
end

-- 随机位置投毒（在常量池中间插入，而不是末尾）
-- 注意：这会改变常量索引，需要调整所有 LOADK 指令
-- 暂时只支持末尾追加
function const_poison.poison_random(proto, options)
    -- 末尾追加是最安全的方式
    return const_poison.poison(proto, options)
end

return const_poison
