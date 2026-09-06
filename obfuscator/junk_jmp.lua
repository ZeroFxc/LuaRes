-- junk_jmp.lua: 垃圾 JMP 指令注入（模仿 main(1).lua 的混淆技术）
-- 注入 sBx=0 的 JMP，跳到下一条指令，不影响执行
-- 用法: local junk_jmp = require("junk_jmp"); junk_jmp.inject(proto, {count=100})

local luac = require("luac")

local junk_jmp = {}

-- 构造一个 sBx=0 的 JMP 指令（跳到下一条指令）
local function make_jmp()
    -- JMP: op=30, sBx=0 -> bx = 0 + 131071 = 131071
    -- 指令 = (bx << 14) | 30
    return (131071 << 14) | 30
end

-- 真正的跳转指令（有 sBx 字段）
-- JMP(30), FORLOOP(39), FORPREP(40), TFORLOOP(42)
-- 注意：LE/LT/EQ/TEST/TESTSET 是条件指令，没有 sBx，不能加入！
local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}

-- 调整跳转指令的 sBx 偏移
-- 在 insert_pos 位置插入 n 条指令后：
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
            -- 跳过 sBx=0 的 JMP（它们跳到下一条指令，不需要调整）
            if op == 30 and sbx == 0 then
                -- do nothing
            else
                local target = i + sbx + 1
                local delta = 0
                if i < insert_pos and target >= insert_pos then
                    delta = n  -- 情况2
                elseif i >= insert_pos and target < insert_pos then
                    delta = -n  -- 情况3
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

-- 条件指令（LE/LT/EQ/TEST/TESTSET）的下一条指令必须是 JMP，不能注入垃圾
local CONDITION_OPS = {[31]=true,[32]=true,[33]=true,[34]=true,[35]=true}

-- 检查注入位置是否安全
local function is_safe_pos(code, pos)
    -- 不能注入到函数末尾（JMP sBx=0 会跳到不存在的下一条指令）
    if pos > #code then
        return false
    end
    -- 不能注入到条件指令的下一条（条件指令 pc++ 会跳过下一条）
    if pos > 1 and pos <= #code then
        local prev_op = code[pos-1] % 64
        if CONDITION_OPS[prev_op] then
            return false
        end
    end
    return true
end

-- 在单个函数中注入垃圾 JMP
local function inject_in_func(p, count)
    count = count or 50
    if count <= 0 then return end

    -- 随机位置注入，同时调整跳转偏移
    local injected = 0
    local attempts = 0
    while injected < count and attempts < count * 10 do
        attempts = attempts + 1
        local pos = math.random(1, #p.code + 1)
        if is_safe_pos(p.code, pos) then
            adjust_jumps(p.code, pos, 1)
            table.insert(p.code, pos, make_jmp())
            injected = injected + 1
        end
    end

    -- 清空 lineinfo
    p.lineinfo = {}
end

-- 主注入函数
function junk_jmp.inject(proto, options)
    options = options or {}
    local count = options.count or 50
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    inject_in_func(proto, count)

    if recursive then
        for i = 1, #proto.p do
            junk_jmp.inject(proto.p[i], {
                count = math.max(5, math.floor(count / 2)),
                recursive = true,
            })
        end
    end

    return proto
end

-- CLI 模式
if arg and arg[0] and arg[0]:match("junk_jmp") and arg[1] then
    local input = arg[1]
    local output = arg[2] or (input:gsub("%.lua$", "_jmp.lua"))
    local count = tonumber(arg[3]) or 100

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    if data:byte(1) ~= 0x1B then
        local func, err = loadfile(input)
        if not func then error("compile error: " .. tostring(err)) end
        data = string.dec(string.dump(func))
    end

    local p = luac.undump(data, false)
    junk_jmp.inject(p, {count = count})
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Injected " .. count .. " junk JMP per function (recursive)")

    local ok, func = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

-- 导出内部函数用于调试
junk_jmp.is_safe_pos = is_safe_pos
junk_jmp.adjust_jumps = adjust_jumps
junk_jmp.make_jmp = make_jmp

return junk_jmp
