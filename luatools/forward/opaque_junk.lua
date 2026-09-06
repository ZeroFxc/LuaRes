-- opaque_junk.lua
-- 不透明谓词垃圾分支填充（学习 layout.lua 的技术）
-- 在真实代码之间插入永远不执行的垃圾分支，增加反编译难度
--
-- 原理:
--   LOADK R(high), 1    -- 加载 true
--   TEST R(high), 0     -- if not R(high) then pc++ (R(high)=true, 不跳过)
--   JMP sBx=N           -- 跳过 N 条垃圾指令
--   [垃圾指令 N 条]      -- 永远不会执行
--   真实代码继续
--
-- 用法: local opaque_junk = require("opaque_junk"); opaque_junk.inject(proto, {count=10})

local luac = require("luac")

local opaque_junk = {}

-- 真正的跳转指令
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

-- 条件指令（下一条必须是 JMP，不能在中间插入）
local CONDITION_OPS = {[31]=true,[32]=true,[33]=true,[34]=true,[35]=true}

-- 构造指令
local function make_loadk(a, bx)
    return (1) | ((a & 0xFF) << 6) | ((bx & 0x3FFFF) << 14)
end

local function make_test(a, c)
    -- TEST A C: andlua 实现与标准 Lua 相反
    -- C=1: if l_isfalse(R(A)) then pc++ (R(A) truthy 时执行 JMP)
    -- C=0: if !l_isfalse(R(A)) then pc++ (R(A) truthy 时跳过 JMP)
    return (34) | ((a & 0xFF) << 6) | ((c & 0x1FF) << 14)
end

local function make_jmp(sbx)
    local bx = sbx + 131071
    return (30) | ((bx & 0x3FFFF) << 14)
end

-- 生成垃圾指令（使用高寄存器，不影响执行）
local function make_junk_inst(high_reg)
    local r = math.random(0, 4)
    if r == 0 then
        -- MOVE high, high
        return (0) | ((high_reg & 0xFF) << 6) | (((high_reg + 1) & 0x1FF) << 23)
    elseif r == 1 then
        -- LOADK high, const (需要常量池有值，用 0)
        return make_loadk(high_reg, 0)
    elseif r == 2 then
        -- NEWTABLE high
        return (10) | ((high_reg & 0xFF) << 6)
    elseif r == 3 then
        -- ADD high, high, high
        return (12) | ((high_reg & 0xFF) << 6) | ((high_reg & 0x1FF) << 23) | ((high_reg & 0x1FF) << 14)
    else
        -- LEN high, high
        return (27) | ((high_reg & 0xFF) << 6) | ((high_reg & 0x1FF) << 23)
    end
end

-- 在单个函数中注入不透明谓词垃圾分支
local function inject_in_func(p, count)
    count = count or 10
    if count <= 0 then return end
    if #p.code < 5 then return end

    -- 高寄存器起始位置
    local old_maxstack = p.maxstacksize
    local extra = math.min(10, 250 - old_maxstack)
    if extra <= 0 then extra = 1 end
    p.maxstacksize = old_maxstack + extra
    local high_reg = old_maxstack

    -- 确保常量池至少有 1 个常量（用于 LOADK）
    if #p.k == 0 then
        table.insert(p.k, 1)
    end

    local injected = 0
    local attempts = 0
    while injected < count and attempts < count * 20 do
        attempts = attempts + 1

        -- 随机选择注入位置（不能在条件指令的下一条，不能在末尾）
        local pos = math.random(1, #p.code - 1)
        if pos > 1 then
            local prev_op = p.code[pos-1] % 64
            if CONDITION_OPS[prev_op] then
                goto continue
            end
        end

        -- 垃圾分支大小（3-8 条）
        local junk_size = math.random(3, 8)

        -- 构建分支: LOADK + TEST + JMP + [junk]
        -- JMP sBx = junk_size (跳过 junk_size 条垃圾指令)
        local branch = {}
        table.insert(branch, make_loadk(high_reg, 0))  -- R(high) = k[0]
        table.insert(branch, make_test(high_reg, 1))     -- if l_isfalse(R(high)) then pc++ (andlua语义)
        table.insert(branch, make_jmp(junk_size))         -- 跳过垃圾指令
        for i = 1, junk_size do
            table.insert(branch, make_junk_inst(high_reg + (i % extra)))
        end

        -- 调整跳转偏移，然后插入
        local branch_len = #branch
        adjust_jumps(p.code, pos, branch_len)
        for i = branch_len, 1, -1 do
            table.insert(p.code, pos, branch[i])
        end
        injected = injected + 1

        ::continue::
    end

    p.lineinfo = {}
end

-- 主注入函数
function opaque_junk.inject(proto, options)
    options = options or {}
    local count = options.count or 10
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    inject_in_func(proto, count)

    if recursive then
        for i = 1, #proto.p do
            opaque_junk.inject(proto.p[i], {
                count = math.max(2, math.floor(count / 2)),
                recursive = true,
            })
        end
    end

    return proto
end

-- CLI 模式
if arg and arg[0] and arg[0]:match("opaque_junk") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_opjunk.lua")
    local count = tonumber(arg[3]) or 10

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    if input:match("%.lua$") then
        local func, err = loadfile(input)
        if not func then error("compile error: " .. err) end
        data = string.dec(string.dump(func))
    end

    local p = luac.undump(data, false)
    opaque_junk.inject(p, {count = count})
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Injected " .. count .. " opaque predicate junk branches")

    local ok, func = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return opaque_junk
