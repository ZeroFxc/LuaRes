-- op48_junk.lua: 无效操作码垃圾指令注入（模仿 main(1).lua 的混淆技术）
-- andlua VM 忽略所有 47-63 的无效操作码，注入后不影响执行
-- 支持多种无效操作码随机注入，让去除更难
-- 特征：A=127 占绝大多数，原始值格式 0xXX9FF0
-- 用法: local op48 = require("op48_junk"); op48.inject(proto, {count=100, multi=true})

local luac = require("luac")

local op48_junk = {}

-- andlua VM 忽略的无效操作码范围（47-63）
local INVALID_OPS = {}
for op = 47, 63 do table.insert(INVALID_OPS, op) end

-- 操作码常量
local OP_MOVE = 0
local OP_LOADK = 1
local OP_LOADBOOL = 3
local OP_JMP = 30
local OP_EQ = 31
local OP_LT = 32
local OP_LE = 33
local OP_TEST = 34
local OP_TESTSET = 35
local OP_CALL = 36
local OP_TAILCALL = 37
local OP_RETURN = 38
local OP_FORLOOP = 39
local OP_FORPREP = 40
local OP_TFORCALL = 41
local OP_TFORLOOP = 42
local OP_CLOSURE = 44
local OP_VARARG = 45

-- 真正的跳转指令（有 sBx 字段）
-- 注意：EQ/LT/LE/TEST/TESTSET 是条件指令，没有 sBx，不能加入！
local JUMP_OPS = {
    [OP_JMP] = true,
    [OP_FORLOOP] = true,
    [OP_FORPREP] = true,
    [OP_TFORLOOP] = true,
}

-- 构造一个垃圾指令（模仿 main(1).lua 的特征）
-- multi=true 时随机选择 47-63 的无效操作码，否则固定用 OP_48
local function make_op48(multi)
    local op = 48
    if multi then
        op = INVALID_OPS[math.random(1, #INVALID_OPS)]
    end
    local a = 127  -- 91.8% 的垃圾指令使用 A=127
    local b = math.random(256, 511)
    local c = math.random(0, 200)
    return (a << 6) | (b << 23) | (c << 14) | op
end

-- 调整跳转指令的 sBx 偏移（在指定位置插入 n 条指令后）
-- 情况1: i<pos 且 target<pos -> sbx 不变
-- 情况2: i<pos 且 target>=pos -> sbx += n
-- 情况3: i>=pos 且 target<pos -> sbx -= n
-- 情况4: i>=pos 且 target>=pos -> sbx 不变
local function adjust_jumps(code, insert_pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            local target = i + sbx + 1
            local delta = 0
            if i < insert_pos and target >= insert_pos then
                delta = n
            elseif i >= insert_pos and target < insert_pos then
                delta = -n
            end
            if delta ~= 0 then
                sbx = sbx + delta
                local new_bx = sbx + 131071
                code[i] = (code[i] & 0x3FFF) | (new_bx << 14)
            end
        end
    end
end

-- 在单个函数中注入垃圾指令
-- mode: "end" 只在末尾注入; "blocks" 在最后一个 RETURN 后注入; "full" 随机位置注入并调整跳转
-- multi: true 时随机使用 47-63 各种无效操作码，false 固定用 OP_48
local function inject_in_func(p, count, mode, multi)
    mode = mode or "end"
    count = count or 50

    if mode == "end" then
        for i = 1, count do
            table.insert(p.code, make_op48(multi))
        end
    elseif mode == "blocks" then
        local last_return = 0
        for i = #p.code, 1, -1 do
            local op = p.code[i] % 64
            if op == OP_RETURN or op == OP_TAILCALL then
                last_return = i
                break
            end
        end
        if last_return > 0 then
            for i = 1, count do
                table.insert(p.code, last_return + 1, make_op48(multi))
            end
        else
            for i = 1, count do
                table.insert(p.code, make_op48(multi))
            end
        end
    elseif mode == "full" then
        -- 随机位置注入，同时调整跳转目标
        for i = 1, count do
            local pos = math.random(1, #p.code + 1)
            adjust_jumps(p.code, pos, 1)
            table.insert(p.code, pos, make_op48(multi))
        end
    end

    -- 清空 lineinfo（数量不匹配会导致问题）
    p.lineinfo = {}
end

-- 主注入函数
function op48_junk.inject(proto, options)
    options = options or {}
    local count = options.count or 50
    local mode = options.mode or "end"
    local multi = options.multi
    if multi == nil then multi = true end  -- 默认开启多操作码
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    inject_in_func(proto, count, mode, multi)

    if recursive then
        for i = 1, #proto.p do
            op48_junk.inject(proto.p[i], {
                count = math.max(10, math.floor(count / 2)),
                mode = mode,
                multi = multi,
                recursive = true,
            })
        end
    end

    return proto
end

-- CLI 模式
if arg and arg[0] and arg[0]:match("op48_junk") and arg[1] then
    local input = arg[1]
    local output = arg[2] or (input:gsub("%.lua$", "_op48.lua"))
    local count = tonumber(arg[3]) or 100
    local mode = arg[4] or "blocks"
    local multi = true
    for i = 5, #arg do
        if arg[i] == "--no-multi" then multi = false end
    end

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    local p = luac.undump(data, false)
    op48_junk.inject(p, {count = count, mode = mode, multi = multi})
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Mode: " .. mode .. ", count per func: " .. count)

    -- 验证
    local ok, func = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return op48_junk
