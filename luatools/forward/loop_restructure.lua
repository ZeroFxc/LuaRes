-- loop_restructure.lua
-- 循环结构重构：把循环体模板插入到正常代码中，跟随正常代码一同执行
-- 插入执行1次的 numeric for 循环，循环体为无副作用垃圾指令
--
-- 模板 (for i=1,1 do junk end):
--   LOADK  R_tmp, 1
--   LOADK  R_tmp+1, 1
--   LOADK  R_tmp+2, 1
--   FORPREP R_tmp, sBx=1   ; 跳到 FORLOOP
--   MOVE   R_tmp+3, R_tmp   ; body (执行1次)
--   FORLOOP R_tmp, sBx=-2   ; 跳回body, 第二次i=2>1退出
--
-- 插入在 proto 开头，所有跳转 target 统一偏移，逻辑不变

local luac = require("luac")

local loop_restructure = {}

local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}

local function make_loadk(a, bx)
    return (1) | ((a & 0xFF) << 6) | ((bx & 0x3FFFF) << 14)
end

local function make_forprep(a, sbx)
    local bx = sbx + 131071
    return (40) | ((a & 0xFF) << 6) | ((bx & 0x3FFFF) << 14)
end

local function make_forloop(a, sbx)
    local bx = sbx + 131071
    return (39) | ((a & 0xFF) << 6) | ((bx & 0x3FFFF) << 14)
end

local function make_move(a, b)
    return (0) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23)
end

local function make_add(a, b, c)
    return (13) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23) | ((c & 0x1FF) << 14)
end

-- 确保常量池有数字 1，返回其索引
local function ensure_const_one(p)
    for i = 1, #p.k do
        if p.k[i] == 1 then return i - 1 end  -- 0-based index
    end
    table.insert(p.k, 1)
    return #p.k - 1
end

-- 修正所有跳转偏移
local function adjust_jumps(code, insert_pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            local target_idx = i + sbx + 1  -- 1-based
            local delta = 0
            if i < insert_pos and target_idx >= insert_pos then
                delta = n
            elseif i >= insert_pos and target_idx < insert_pos then
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

-- 生成循环模板（body_size 条垃圾指令）
local function make_loop_template(tmp_reg, one_idx, body_size)
    local t = {}
    table.insert(t, make_loadk(tmp_reg, one_idx))
    table.insert(t, make_loadk(tmp_reg + 1, one_idx))
    table.insert(t, make_loadk(tmp_reg + 2, one_idx))
    -- FORPREP sBx=1: 跳到 FORLOOP (body_size+1 条之后)
    -- FORPREP 在 index 3 (0-based pc=3), FORLOOP 在 pc=3+1+body_size = 4+body_size
    -- sBx = target_pc - (forprep_pc + 1) = (4+body_size) - 4 = body_size
    table.insert(t, make_forprep(tmp_reg, body_size))
    -- body
    for i = 1, body_size do
        if i % 2 == 1 then
            table.insert(t, make_move(tmp_reg + 3, tmp_reg))
        else
            table.insert(t, make_add(tmp_reg + 3, tmp_reg + 3, tmp_reg))
        end
    end
    -- FORLOOP sBx=-body_size-1: 跳回 body 第一条
    -- FORLOOP pc = 4 + body_size, body start pc = 4
    -- sBx = 4 - (4+body_size+1) = -body_size - 1
    table.insert(t, make_forloop(tmp_reg, -body_size - 1))
    return t
end

local function inject_in_func(p, count)
    count = count or 3
    if count <= 0 then return 0 end
    if #p.code < 2 then return 0 end

    local one_idx = ensure_const_one(p)

    local old_maxstack = p.maxstacksize
    local extra = 5
    if old_maxstack + extra > 255 then extra = 255 - old_maxstack end
    if extra < 4 then return 0 end
    p.maxstacksize = old_maxstack + extra
    local tmp_reg = old_maxstack

    local total = 0
    for loop = 1, count do
        local body_size = math.random(2, 5)
        local tmpl = make_loop_template(tmp_reg, one_idx, body_size)
        local tmpl_len = #tmpl

        -- 在 proto 开头插入（位置1），所有跳转 target 都 +tmpl_len
        adjust_jumps(p.code, 1, tmpl_len)
        for j = tmpl_len, 1, -1 do
            table.insert(p.code, 1, tmpl[j])
        end
        total = total + 1
    end

    p.lineinfo = {}
    return total
end

function loop_restructure.inject(proto, options)
    options = options or {}
    local count = options.count or 3
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    local total = inject_in_func(proto, count)

    if recursive then
        for i = 1, #proto.p do
            total = total + loop_restructure.inject(proto.p[i], {
                count = math.max(1, math.floor(count / 2)),
                recursive = true,
            })
        end
    end

    return total
end

-- CLI
if arg and arg[0] and arg[0]:match("loop_restructure") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_lr.lua")
    local count = tonumber(arg[3]) or 3

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    if input:match("%.lua$") then
        local func, err = loadfile(input)
        if not func then error("compile error: " .. err) end
        data = string.dec(string.dump(func))
    end

    local p = luac.undump(data, false)
    local n = loop_restructure.inject(p, {count = count})
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Injected " .. n .. " loop templates")

    local ok, func = pcall(load, out)
    print("Load test: " .. tostring(ok))
    if ok then
        local ok2, err = pcall(func)
        print("Run test: " .. tostring(ok2) .. (err and " " .. tostring(err) or ""))
    end
end

return loop_restructure
