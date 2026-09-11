-- junk_move.lua
-- 垃圾 MOVE 指令注入：高寄存器间复制，不影响后续执行
-- 学习 main(1).lua 的特征：大量使用高寄存器的垃圾指令
--
-- 用法: local junk_move = require("junk_move"); junk_move.inject(proto, {count=100})

local luac = require("luac")

local junk_move = {}

-- 真正的跳转指令（有 sBx 字段）
local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}

-- 调整跳转指令的 sBx 偏移
local function adjust_jumps(code, insert_pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            if op == 30 and sbx == 0 then
                -- skip sBx=0 JMP
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

-- 条件指令（下一条必须是 JMP，不能注入）
local CONDITION_OPS = {[31]=true,[32]=true,[33]=true,[34]=true,[35]=true}

-- 构造 MOVE 指令：R(A) = R(B)
local function make_move(a, b)
    return (0) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23)
end

-- 在单个函数中注入垃圾 MOVE
local function inject_in_func(p, count)
    count = count or 50
    if count <= 0 then return end

    -- maxstacksize 限制（8 位存储，不超过 250）
    local old_maxstack = p.maxstacksize
    local extra_regs = math.min(count, 20)
    local new_maxstack = math.min(old_maxstack + extra_regs, 250)
    p.maxstacksize = new_maxstack
    local usable_high = new_maxstack - old_maxstack
    if usable_high <= 0 then usable_high = 1 end

    -- 随机位置注入 MOVE，源和目标都是高寄存器
    local injected = 0
    local attempts = 0
    while injected < count and attempts < count * 10 do
        attempts = attempts + 1
        local pos = math.random(1, #p.code)

        -- 源和目标都是高寄存器
        local a = old_maxstack + math.random(0, usable_high - 1)
        local b = old_maxstack + math.random(0, usable_high - 1)

        -- 确保不注入到条件指令的下一条
        if pos > 1 then
            local prev_op = p.code[pos-1] % 64
            if CONDITION_OPS[prev_op] then
                goto continue
            end
        end
        -- 不能注入到函数末尾
        if pos > #p.code then
            goto continue
        end

        adjust_jumps(p.code, pos, 1)
        table.insert(p.code, pos, make_move(a, b))
        injected = injected + 1
        ::continue::
    end

    p.lineinfo = {}
end

-- 主注入函数
function junk_move.inject(proto, options)
    options = options or {}
    local count = options.count or 50
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    inject_in_func(proto, count)

    if recursive then
        for i = 1, #proto.p do
            junk_move.inject(proto.p[i], {
                count = math.max(5, math.floor(count / 2)),
                recursive = true,
            })
        end
    end

    return proto
end

-- CLI 模式
if arg and arg[0] and arg[0]:match("junk_move") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_junkmove.lua")
    local count = tonumber(arg[3]) or 50

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    if input:match("%.lua$") then
        local func, err = loadfile(input)
        if not func then error("compile error: " .. err) end
        data = string.dec(string.dump(func))
    end

    local p = luac.undump(data, false)
    junk_move.inject(p, {count = count})
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Injected " .. count .. " junk MOVE per function (recursive)")

    local ok, func = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return junk_move
