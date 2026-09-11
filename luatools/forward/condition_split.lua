-- condition_split.lua
-- 单个判断条件拆分为多个判断条件
-- 在 LT/LE/EQ + JMP 模式前插入一个总是通过的条件检查
--
-- 原始:  LT/LE/EQ A=0  +  JMP(exit)  +  body
-- 拆分:  LOADBOOL(true) + TEST(C=1,skip) + JMP(exit) + LT/LE/EQ A=0 + JMP(exit) + body
-- 新条件总是 true，TEST 跳过 JMP，继续执行原始条件，逻辑等价

local luac = require("luac")

local condition_split = {}

local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}
local COMPARE_OPS = {[31]=true,[32]=true,[33]=true} -- EQ, LT, LE

local function make_loadbool(a, b)
    -- LOADBOOL A B C: R(A) = (B != 0), if C then pc++
    -- B in bits 23-31, C in bits 14-22
    return (3) | ((a & 0xFF) << 6) | ((b & 0x1FF) << 23)
end

local function make_test(a, c)
    return (34) | ((a & 0xFF) << 6) | ((c & 0x1FF) << 14)
end

local function make_jmp(sbx)
    local bx = sbx + 131071
    return (30) | ((bx & 0x3FFFF) << 14)
end

-- 修正所有跳转偏移（在 insert_pos 插入 n 条指令后）
local function adjust_jumps(code, insert_pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            local target = i + sbx  -- 1-based: target index = i + sbx (因为 pc=i-1, target_pc=pc+1+sbx=i+sbx, 1-based index=target_pc+1=i+sbx+1... 让我重算)
            -- pc (0-based) = i-1, target_pc = pc+1+sbx = i+sbx
            -- 1-based index = target_pc + 1 = i+sbx+1
            local target_idx = i + sbx + 1
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

local function split_in_func(p, count)
    count = count or 5
    if count <= 0 then return 0 end
    if #p.code < 3 then return 0 end

    local old_maxstack = p.maxstacksize
    local extra = 2
    if old_maxstack + extra > 255 then extra = 1 end
    p.maxstacksize = old_maxstack + extra
    local tmp_reg = old_maxstack

    local changes = 0
    local i = 1
    while i <= #p.code - 1 and changes < count do
        local op = p.code[i] % 64
        local next_op = p.code[i+1] % 64
        if COMPARE_OPS[op] and next_op == 30 then
            -- 找到比较指令 + JMP
            -- 原始 JMP 的 target (1-based index)
            local orig_jmp_bx = p.code[i+1] >> 14
            local orig_jmp_sbx = orig_jmp_bx - 131071
            local orig_target_idx = (i+1) + orig_jmp_sbx + 1  -- 1-based

            -- 插入3条指令在位置 i
            -- 插入3条指令在位置 i (1-based): LOADBOOL(i), TEST(i+1), JMP(i+2)
            -- 新 JMP 在 1-based index = i+2
            local new_jmp_idx = i + 2
            -- target 若在插入点(i)或之后则 +3，否则不变（向后跳转如 repeat-until）
            local new_target_idx = orig_target_idx >= i and orig_target_idx + 3 or orig_target_idx
            local new_sbx = new_target_idx - new_jmp_idx - 1

            local branch = {
                make_loadbool(tmp_reg, 1),  -- R(tmp) = true
                make_test(tmp_reg, 0),      -- 此Lua: C=0+true -> !isfalse(true)=true -> skip next JMP
                make_jmp(new_sbx),          -- 被 skip，永远不执行
            }

            adjust_jumps(p.code, i, 3)
            for j = 3, 1, -1 do
                table.insert(p.code, i, branch[j])
            end
            changes = changes + 1
            i = i + 3  -- 跳过插入的指令和原始比较指令
        end
        i = i + 1
    end

    p.lineinfo = {}
    return changes
end

function condition_split.inject(proto, options)
    options = options or {}
    local count = options.count or 5
    local recursive = options.recursive
    if recursive == nil then recursive = true end

    local total = split_in_func(proto, count)

    if recursive then
        for i = 1, #proto.p do
            total = total + condition_split.inject(proto.p[i], {
                count = math.max(1, math.floor(count / 2)),
                recursive = true,
            })
        end
    end

    return total
end

-- CLI
if arg and arg[0] and arg[0]:match("condition_split") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_cs.lua")
    local count = tonumber(arg[3]) or 5

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    if input:match("%.lua$") then
        local func, err = loadfile(input)
        if not func then error("compile error: " .. err) end
        data = string.dec(string.dump(func))
    end

    local p = luac.undump(data, false)
    local n = condition_split.inject(p, {count = count})
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Split " .. n .. " conditions")

    local ok, func = pcall(load, out)
    print("Load test: " .. tostring(ok))
    if ok then
        local ok2, err = pcall(func)
        print("Run test: " .. tostring(ok2) .. (err and " " .. tostring(err) or ""))
    end
end

return condition_split
