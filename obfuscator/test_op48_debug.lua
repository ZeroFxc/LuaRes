local luac = require("luac")
local op48 = require("op48_junk")

local test_code = [[
local function fib(n)
    if n <= 1 then return n end
    return fib(n-1) + fib(n-2)
end
for i = 1, 5 do
    print("fib(" .. i .. ")=" .. fib(i))
end
print("done")
]]

local func = load(test_code)
local bc = string.dec(string.dump(func))

-- 只在 main 函数注入（recursive=false）
print("=== blocks mode, main only ===")
local p = luac.undump(bc, false)
op48.inject(p, {count = 20, mode = "blocks", recursive = false})
print("main code count: " .. #p.code)
for i = 1, #p.code do
    local op = p.code[i] % 64
    print(string.format("  [%d] 0x%08X op=%d", i, p.code[i], op))
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
