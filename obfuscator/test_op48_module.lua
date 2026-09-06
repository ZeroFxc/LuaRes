local luac = require("luac")
local op48 = require("op48_junk")

-- 测试代码（有循环、条件、函数调用）
local test_code = [[
local function fib(n)
    if n <= 1 then return n end
    return fib(n-1) + fib(n-2)
end
for i = 1, 10 do
    print("fib(" .. i .. ")=" .. fib(i))
end
print("done")
]]

local func = load(test_code)
local bc = string.dec(string.dump(func))
print("Original size: " .. #bc)

-- 测试三种模式
local modes = {"end", "blocks", "full"}
for _, mode in ipairs(modes) do
    print("\n=== Mode: " .. mode .. " ===")
    local p = luac.undump(bc, false)
    op48.inject(p, {count = 30, mode = mode})
    local out = luac.dump(p)
    print("Output size: " .. #out)

    -- 统计 OP_48 数量
    local op48_count = 0
    local function count_op48(pp)
        for i = 1, #pp.code do
            if pp.code[i] % 64 == 48 then op48_count = op48_count + 1 end
        end
        for i = 1, #pp.p do count_op48(pp.p[i]) end
    end
    local p2 = luac.undump(out, false)
    count_op48(p2)
    print("OP_48 count: " .. op48_count)

    -- 验证执行
    local ok, f = pcall(load, out)
    print("Load: " .. tostring(ok))
    if ok then
        -- 捕获输出
        local old_print = print
        local outputs = {}
        print = function(...)
            local args = {...}
            local s = ""
            for i, v in ipairs(args) do
                if i > 1 then s = s .. "\t" end
                s = s .. tostring(v)
            end
            table.insert(outputs, s)
        end
        local exec_ok, exec_err = pcall(f)
        print = old_print
        print("Execute: " .. tostring(exec_ok))
        if exec_ok then
            print("Last output: " .. outputs[#outputs])
            print("Output count: " .. #outputs)
        else
            print("Error: " .. tostring(exec_err))
        end
    else
        print("Error: " .. tostring(f))
    end
end

-- 写入测试文件（用 blocks 模式）
print("\n=== Writing test file ===")
local p = luac.undump(bc, false)
op48.inject(p, {count = 50, mode = "blocks"})
local out = luac.dump(p)
local fout = io.open("E:/LuaRes/luasafe/test_op48_output.lua", "wb")
fout:write(out)
fout:close()
print("Written: E:/LuaRes/luasafe/test_op48_output.lua (" .. #out .. " bytes)")
