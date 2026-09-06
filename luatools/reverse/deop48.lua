-- deop48.lua: 无效操作码垃圾指令分析与去除工具
-- 功能：分析字节码中所有无效操作码(>46)的数量/分布，安全去除
-- andlua VM 忽略 47-63 的所有无效操作码，这些通常是混淆注入的垃圾
-- 用法作为库:
--   local deop48 = require("deop48")
--   local stats = deop48.analyze(proto)
--   deop48.remove(proto)
-- 用法作为CLI:
--   lua deop48.lua <input.lua> [output.lua] [--analyze|--remove]

local luac = require("luac")

local deop48 = {}

-- andlua VM 忽略的无效操作码范围（47-63）
local function is_invalid_op(op)
    return op > 46
end

-- 分析单个函数中的无效操作码
local function analyze_func(pp, path, result)
    local count = 0
    local positions = {}
    for i = 1, #pp.code do
        local op = pp.code[i] % 64
        if is_invalid_op(op) then
            count = count + 1
            if #positions < 20 then
                local inst = pp.code[i]
                local a = (inst >> 6) & 0xFF
                local b = (inst >> 23) & 0x1FF
                local c = (inst >> 14) & 0x1FF
                table.insert(positions, {idx=i, raw=inst, a=a, b=b, c=c})
            end
        end
    end

    table.insert(result.funcs, {
        path = path,
        code_count = #pp.code,
        op48_count = count,
        ratio = count > 0 and (count / #pp.code * 100) or 0,
        samples = positions,
    })
    result.total_code = result.total_code + #pp.code
    result.total_op48 = result.total_op48 + count

    for i = 1, #pp.p do
        analyze_func(pp.p[i], path .. "/" .. i, result)
    end
end

-- 分析整个 proto 树中的 OP_48
function deop48.analyze(proto)
    local result = {
        total_code = 0,
        total_op48 = 0,
        funcs = {},
    }
    analyze_func(proto, "main", result)
    result.total_ratio = result.total_code > 0 and (result.total_op48 / result.total_code * 100) or 0
    return result
end

-- 打印分析结果
function deop48.print_stats(stats)
    print("=== Invalid Opcode Analysis ===")
    print("Total instructions: " .. stats.total_code)
    print("Invalid op count: " .. stats.total_op48)
    print(string.format("Invalid op ratio: %.2f%%", stats.total_ratio))
    print("\nPer-function breakdown:")
    for _, f in ipairs(stats.funcs) do
        if f.op48_count > 0 then
            print(string.format("  %s: %d/%d (%.1f%%)",
                f.path, f.op48_count, f.code_count, f.ratio))
            if #f.samples > 0 then
                for _, s in ipairs(f.samples) do
                    print(string.format("    [%d] raw=0x%08X A=%d B=%d C=%d",
                        s.idx, s.raw, s.a, s.b, s.c))
                end
            end
        end
    end
end

-- 会改变控制流的指令（需要调整 sBx 偏移）
local JUMP_OPS = {
    [30] = true,  -- OP_JMP
    [39] = true,  -- OP_FORLOOP
    [40] = true,  -- OP_FORPREP
    [42] = true,  -- OP_TFORLOOP
    [31] = true,  -- OP_EQ
    [32] = true,  -- OP_LT
    [33] = true,  -- OP_LE
    [34] = true,  -- OP_TEST
    [35] = true,  -- OP_TESTSET
}

-- 去除单个函数中的无效操作码，并调整跳转偏移
local function remove_func(pp)
    if #pp.code == 0 then return 0 end

    -- 第一步：标记哪些位置是无效操作码
    local is_op48 = {}
    for i = 1, #pp.code do
        is_op48[i] = is_invalid_op(pp.code[i] % 64)
    end

    -- 第二步：计算每个原始位置到新位置的映射
    -- new_pos[i] = 原始位置 i 对应的新位置（如果 i 是 OP_48 则为 nil）
    local new_pos = {}
    local offset = 0
    for i = 1, #pp.code do
        if is_op48[i] then
            offset = offset + 1
        else
            new_pos[i] = i - offset
        end
    end

    -- 第三步：构建新的 code 数组，同时调整跳转偏移
    local new_code = {}
    local removed = 0
    for i = 1, #pp.code do
        if not is_op48[i] then
            local inst = pp.code[i]
            local op = inst % 64
            if JUMP_OPS[op] then
                -- 读取 sBx
                local bx = inst >> 14
                local sbx = bx - 131071
                -- 计算跳转目标（原始位置）
                local target = i + sbx + 1
                -- 如果目标在范围内，转换为新位置
                if target >= 1 and target <= #pp.code then
                    local new_target = new_pos[target]
                    if new_target then
                        -- 计算新的 sBx
                        local new_sbx = new_target - (i - offset) - 1
                        -- 注意：i - offset 是当前指令在新数组中的位置
                        -- 但 offset 是到当前位置为止移除的 OP_48 数量
                        -- 需要重新计算当前指令的新位置
                        local current_new_pos = new_pos[i]
                        new_sbx = new_target - current_new_pos - 1
                        local new_bx = new_sbx + 131071
                        inst = (inst & 0x3FFF) | (new_bx << 14)
                    end
                end
            end
            table.insert(new_code, inst)
        else
            removed = removed + 1
        end
    end

    if removed > 0 then
        pp.code = new_code
        -- lineinfo 数量可能不匹配，清空它
        if #pp.lineinfo ~= #pp.code then
            pp.lineinfo = {}
        end
    end

    for i = 1, #pp.p do
        removed = removed + remove_func(pp.p[i])
    end

    return removed
end

-- 去除整个 proto 树中的 OP_48
function deop48.remove(proto)
    return remove_func(proto)
end

-- CLI 模式
if arg and arg[0] and arg[0]:match("deop48") and arg[1] then
    local input = arg[1]
    local mode = "remove"  -- 默认去除
    local output = nil

    for i = 2, #arg do
        if arg[i] == "--analyze" then
            mode = "analyze"
        elseif arg[i] == "--remove" then
            mode = "remove"
        elseif arg[i]:match("%.lua$") or arg[i]:match("%.luac$") then
            if not output then output = arg[i] end
        end
    end

    if not output then
        output = input:gsub("%.lua$", "_deop48.lua")
    end

    local f = io.open(input, "rb")
    if not f then error("cannot open " .. input) end
    local data = f:read("*a")
    f:close()

    -- 如果是源码，先编译
    if data:byte(1) ~= 0x1B then
        local func, err = loadfile(input)
        if not func then error("compile error: " .. tostring(err)) end
        data = string.dec(string.dump(func))
    end

    local proto = luac.undump(data, false)

    if mode == "analyze" then
        local stats = deop48.analyze(proto)
        deop48.print_stats(stats)
    else
        -- 先分析
        local stats_before = deop48.analyze(proto)
        print("Before: " .. stats_before.total_op48 .. " invalid ops / " .. stats_before.total_code .. " instructions")

        -- 去除
        local removed = deop48.remove(proto)
        print("Removed: " .. removed .. " invalid instructions")

        -- 验证
        local stats_after = deop48.analyze(proto)
        print("After: " .. stats_after.total_op48 .. " invalid ops / " .. stats_after.total_code .. " instructions")

        -- dump
        local out = luac.dump(proto)
        local fout = io.open(output, "wb")
        fout:write(out)
        fout:close()
        print("Written: " .. output .. " (" .. #out .. " bytes)")

        -- 验证可以加载
        local ok, func = pcall(load, out)
        print("Load test: " .. tostring(ok))
    end
end

return deop48
