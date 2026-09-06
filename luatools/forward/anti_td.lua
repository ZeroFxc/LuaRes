-- anti_td.lua: Anti-TD decompiler protection for andlua Lua 5.3 bytecode
-- 利用 andlua 加载器不校验的字段，干扰 TD 反编译器
-- 注意：LUAC_NUM=370.5 是 andlua 内核内置的，不需要在这里处理

local luac = require("luac")

-- 设置随机种子，确保每次运行生成不同的垃圾数据
math.randomseed(os.time() + math.floor(os.clock() * 1000000))
-- 消耗前几个随机数（Lua 的 math.random 前几个值分布不好）
for _ = 1, 10 do math.random() end

local anti_td = {}

-- 垃圾字符串生成器
local function junk_string(len)
    local chars = {}
    for i = 1, len do
        chars[i] = string.char(math.random(0x80, 0xFF))
    end
    return table.concat(chars)
end

-- 篡改函数头：numparams/is_vararg/maxstack 设为异常值
-- andlua 加载器忽略这些字段的校验，但 TD 会校验
local function poison_header(p, is_main)
    if is_main then
        p.numparams = 255
        p.is_vararg = 250
        p.maxstacksize = 250
        p.linedefined = 0xDEADBEEF
        p.lastlinedefined = -1
    else
        -- 子函数也可以轻度污染，但太激进可能导致加载问题
        -- 这里只污染 maxstack（设为较大但合理的值）
        if p.maxstacksize < 10 then
            p.maxstacksize = math.max(p.maxstacksize, 2)
        end
    end
    -- 递归处理子函数
    for i = 1, #p.p do
        poison_header(p.p[i], false)
    end
end

-- 清零所有函数的 lineinfo
-- TD 反编译需要行信息，清零后 TD 无法正确反编译
-- andlua 加载器不要求 lineinfo 数量与 code 匹配
local function strip_lineinfo(p)
    p.lineinfo = {}
    p.locvars = {}
    -- upvalue names 也可以清零
    for i = 1, #p.upvalues do
        p.upvalues[i].name = ""
    end
    for i = 1, #p.p do
        strip_lineinfo(p.p[i])
    end
end

-- 注入垃圾 source 字符串
-- source 字符串会被 TD 显示，但不影响执行
local function inject_junk_source(p, is_main)
    if is_main then
        local junk = junk_string(200)
        p.source = junk
    end
    for i = 1, #p.p do
        inject_junk_source(p.p[i], false)
    end
end

-- 注入垃圾 upvalue 数据（防 TD 的关键手段）
-- 注意：只能在 main 函数注入！子函数绝对不能注入垃圾 upvalue，
-- 因为 CLOSURE 指令创建子函数时会受 sizeupvalues 影响，导致执行崩溃。
-- 防td.lua 也是只在 main 注入 573 个垃圾 upvalue，子函数全是真实的。
-- TD 解析时会读取 upvalue 描述符，注入非法 instack 值和大量 upvalue 导致解析失败
-- andlua 加载器忽略 main 函数的 upvalue 描述符（实际 upvalue 由 CLOSURE 指令决定）
local function inject_junk_upvalues(p, is_main)
    if is_main then
        -- 保存原始 upvalues
        local orig_uv = {}
        for i = 1, #p.upvalues do table.insert(orig_uv, p.upvalues[i]) end
        -- 注入 200-500 个垃圾 upvalue
        local junk_count = math.random(200, 500)
        local junk_uv = {}
        for i = 1, junk_count do
            table.insert(junk_uv, {
                instack = math.random(2, 255),  -- 非法值（正常只能是 0/1）
                idx = math.random(0, 255),
                name = junk_string(math.random(5, 20)),
            })
        end
        p.upvalues = junk_uv
        p.sizeupvalues = junk_count
    end
    for i = 1, #p.p do
        inject_junk_upvalues(p.p[i], false)
    end
end

-- 注入乱码常量到常量池
-- 在常量池末尾添加不可打印字符串和异常数值
-- 注意：这些常量不会被 code 引用，所以不影响执行
local function inject_junk_constants(p, is_main)
    if is_main then
        -- 添加几个乱码字符串常量
        table.insert(p.k, junk_string(50))
        table.insert(p.k, junk_string(30))
        table.insert(p.k, 0xDEADBEEF)
        table.insert(p.k, -0xCAFEBABE)
    end
    for i = 1, #p.p do
        inject_junk_constants(p.p[i], false)
    end
end

-- 主保护函数
-- options: {
--   poison_header = true,   -- 篡改函数头
--   strip_lineinfo = true,  -- 清限行信息
--   junk_source = true,     -- 注入垃圾 source
--   junk_upvalues = true,   -- 注入垃圾 upvalue（防 TD 关键手段）
--   junk_constants = false, -- 注入乱码常量（可能增加体积）
-- }
function anti_td.protect(proto, options)
    options = options or {}
    if options.poison_header == nil then options.poison_header = true end
    if options.strip_lineinfo == nil then options.strip_lineinfo = true end
    if options.junk_source == nil then options.junk_source = true end
    if options.junk_upvalues == nil then options.junk_upvalues = true end
    if options.junk_constants == nil then options.junk_constants = false end

    if options.poison_header then
        poison_header(proto, true)
    end
    if options.strip_lineinfo then
        strip_lineinfo(proto)
    end
    if options.junk_source then
        inject_junk_source(proto, true)
    end
    if options.junk_upvalues then
        inject_junk_upvalues(proto, true)
    end
    if options.junk_constants then
        inject_junk_constants(proto, true)
    end
    return proto
end

-- CLI 模式
local MODULE_NAME = ...
if not MODULE_NAME then
    local input = arg[1]
    local output = arg[2]
    if not input or not output then
        print("Usage: lua_luac.exe anti_td.lua <input.lua> <output.lua>")
        os.exit(1)
    end
    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()
    local p = luac.undump(data, false)
    anti_td.protect(p, {junk_constants = true})
    local out = luac.dump(p)
    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()
    print("Protected: " .. #data .. " -> " .. #out .. " bytes")
end

return anti_td
