local luac = require("luac")

local test_code = [[
local function fib(n)
    if n <= 1 then return n end
    return fib(n-1) + fib(n-2)
end
print(fib(5))
]]

local func = load(test_code)
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

print("Main code count: " .. #p.code)
print("Sub function count: " .. #p.p)
if #p.p > 0 then
    local sub = p.p[1]
    print("Sub code count: " .. #sub.code)
    for i = 1, #sub.code do
        local op = sub.code[i] % 64
        print(string.format("  [%d] 0x%08X op=%d", i, sub.code[i], op))
    end

    -- 在子函数的 RETURN 之后注入 5 个 OP_48
    local function make_op48()
        local a = 127
        local b = math.random(256, 511)
        local c = math.random(0, 200)
        return (a << 6) | (b << 23) | (c << 14) | 48
    end

    -- 找到子函数中的 RETURN
    local returns = {}
    for i = 1, #sub.code do
        if sub.code[i] % 64 == 38 then
            table.insert(returns, i)
        end
    end
    print("RETURN positions: " .. table.concat(returns, ", "))

    -- 在每个 RETURN 之后注入 3 个 OP_48
    for idx = #returns, 1, -1 do
        local pos = returns[idx] + 1
        for j = 1, 3 do
            table.insert(sub.code, pos, make_op48())
        end
    end
    sub.lineinfo = {}

    print("Sub code count after injection: " .. #sub.code)
end

local out = luac.dump(p)
print("Output size: " .. #out)
local ok, f = pcall(load, out)
print("Load: " .. tostring(ok))
if ok then
    f()
else
    print("Error: " .. tostring(f))
end
