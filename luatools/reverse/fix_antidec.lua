-- fix_antidec.lua: 修复被 anti-TD 混淆的 andlua Lua 5.3 字节码
-- andlua header 格式: 33 字节 (4 sig + 1 ver + 1 fmt + 6 LUAC_DATA + 5 sizes + 8 LUAC_INT + 8 LUAC_NUM)
-- 用法 as library: local fix_antidec = require("fix_antidec"); fix_antidec.fix(proto)
-- 用法 as CLI: lua_luac.exe fix_antidec.lua <input.lua> <output.lua>

local luac = require("luac")

local fix_antidec = {}

-- 计算代码中实际使用的最大寄存器编号
local function calc_max_reg(p)
    local max_r = 1
    for i = 1, #p.code do
        local inst = p.code[i]
        local op = inst % 64
        local a = (inst >> 6) & 0xFF
        local b = (inst >> 23) & 0x1FF
        local c = (inst >> 14) & 0x1FF
        if a > max_r then max_r = a end
        if b < 256 and b > max_r then max_r = b end
        if c < 256 and c > max_r then max_r = c end
        -- CALL/TAILCALL/RETURN 的 B 字段可能表示多参数
        if (op == 36 or op == 37 or op == 38) and b == 0 then
            -- 多参数，不影响 maxstacksize 计算
        end
    end
    return math.min(max_r + 1, 255)  -- +1 因为寄存器编号从 0 开始；maxstacksize 是 8 位，最大 255
end

local function fix_proto(p, is_main)
    -- 计算实际需要的 maxstacksize
    local needed_stack = calc_max_reg(p)

    -- 修复函数头异常字段
    if is_main then
        p.numparams = 0
        p.is_vararg = 0
        -- 不盲目设为 2，根据代码实际需求设置
        if p.maxstacksize > 200 or p.maxstacksize < needed_stack then
            p.maxstacksize = needed_stack
        end
        p.linedefined = 0
        p.lastlinedefined = 0
    else
        if p.numparams > 100 then p.numparams = 0 end
        if p.is_vararg > 2 then p.is_vararg = 0 end
        -- 不盲目设为 2，根据代码实际需求设置
        if p.maxstacksize > 100 or p.maxstacksize < needed_stack then
            p.maxstacksize = needed_stack
        end
        if p.linedefined > 1000000 then p.linedefined = 0 end
        if p.lastlinedefined < 0 then p.lastlinedefined = 0 end
    end

    -- 修复 sizeupvalues 异常
    -- anti-td 直接用垃圾 upvalues 替换所有原始 upvalues（instack=2-255 非法值）
    -- andlua 加载器忽略 main 函数的 upvalue 描述符，实际 upvalue 由 CLOSURE 决定
    -- 所以如果所有 upvalue 的 instack 都是异常值，说明是 anti-td 注入的垃圾
    -- 需要恢复 main 函数的 upvalue 为 _ENV（通常 1 个，instack=1, idx=0）
    if is_main and p.sizeupvalues > 50 then
        -- 检查是否所有 upvalue 的 instack 都是异常值
        local all_junk = true
        for i = 1, #p.upvalues do
            local uv = p.upvalues[i]
            if uv.instack == 0 or uv.instack == 1 then
                all_junk = false
                break
            end
        end
        if all_junk then
            -- 恢复为 1 个 _ENV upvalue
            p.upvalues = {{instack = 1, idx = 0, name = "_ENV"}}
            p.sizeupvalues = 1
        else
            -- 有真实 upvalue，只删除 instack 异常的
            local new_uv = {}
            for i = 1, #p.upvalues do
                local uv = p.upvalues[i]
                if uv.instack == 0 or uv.instack == 1 then
                    table.insert(new_uv, uv)
                end
            end
            p.upvalues = new_uv
            p.sizeupvalues = #new_uv
        end
    elseif p.sizeupvalues > 50 then
        -- 子函数：只删除 instack 异常的 upvalue
        local new_uv = {}
        for i = 1, #p.upvalues do
            local uv = p.upvalues[i]
            if uv.instack == 0 or uv.instack == 1 then
                table.insert(new_uv, uv)
            end
        end
        if #new_uv ~= #p.upvalues then
            p.upvalues = new_uv
            p.sizeupvalues = #new_uv
        end
    end

    -- 修复异常的 upvalue 数据（instack 只能是 0 或 1）
    if p.sizeupvalues > 0 and p.sizeupvalues <= 50 then
        local new_uv = {}
        for i = 1, #p.upvalues do
            local uv = p.upvalues[i]
            if uv.instack == 0 or uv.instack == 1 then
                table.insert(new_uv, uv)
            end
        end
        if #new_uv ~= #p.upvalues then
            p.upvalues = new_uv
            p.sizeupvalues = #new_uv
        end
    end

    -- 修复 lineinfo：如果数量与 code 不匹配，重建为全 0
    if #p.lineinfo ~= #p.code then
        local new_lineinfo = {}
        for i = 1, #p.code do new_lineinfo[i] = 0 end
        p.lineinfo = new_lineinfo
    end

    -- 修复 locvars：异常数量清零
    if #p.locvars > 1000 then
        p.locvars = {}
    end

    -- 递归修复子函数
    for i = 1, #p.p do
        fix_proto(p.p[i], false)
    end
end

function fix_antidec.fix(proto, options)
    options = options or {}
    fix_proto(proto, true)
    return 0  -- 返回移除的指令数（anti-td 不移除指令，只修复头部）
end

-- CLI
if arg and arg[0] and arg[0]:match("fix_antidec") and arg[1] and arg[2] then
    local input = arg[1]
    local output = arg[2]

    local f = io.open(input, "rb")
    if not f then
        print("Error: cannot open " .. input)
        os.exit(1)
    end
    local data = f:read("*a")
    f:close()

    print("Input size: " .. #data .. " bytes")

    -- 修复 header (LUAC_NUM)
    local luac_num = string.char(0x18, 0x2D, 0x44, 0x54, 0xFB, 0x21, 0x09, 0x40)
    data = data:sub(1, 25) .. luac_num .. data:sub(34)
    print("Header LUAC_NUM fixed")

    -- undump
    local p = luac.undump(data, false)
    print("Undump OK")

    -- 统计
    local function count(p)
        local c = 1
        for i = 1, #p.p do c = c + count(p.p[i]) end
        return c
    end
    print("Total functions: " .. count(p))

    -- 修复所有函数
    fix_antidec.fix(p)
    print("All protos fixed")

    -- dump
    local out = luac.dump(p)
    print("Output size: " .. #out .. " bytes")

    -- 测试 load
    local ok, err = pcall(load, out)
    print("Load test: " .. tostring(ok))
    if not ok then print("  Error: " .. tostring(err)) end

    -- 写入
    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()
    print("Written to " .. output)
end

return fix_antidec
