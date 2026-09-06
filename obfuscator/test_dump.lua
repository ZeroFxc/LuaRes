-- 测试1：简单 for 循环（不崩溃）
local code1 = [[
local function test1()
    local s = "require \"test.module\""
    for m, n in s:gmatch("require *%(? *\"([%w_]+)%.?([%w_]*)") do
        local cp = string.format("lib%s.so", m)
    end
end
]]
local f1, err = load(code1)
if not f1 then print("load1 error:", err) os.exit(1) end
local ok, r = pcall(string.dump, f1, true)
if ok then print("test1 dump ok, size:", #r) else print("test1 dump error:", r) end

-- 测试2：包含 if 分支的 for 循环（崩溃）
local code2 = [[
local function test2()
    local s = "require \"test.module\""
    for m, n in s:gmatch("require *%(? *\"([%w_]+)%.?([%w_]*)") do
        local cp = string.format("lib%s.so", m)
        if n ~= "" then
            local lp = string.format("lua/%s.lua", m)
            m = m .. '/' .. n
        end
    end
end
]]
local f2, err = load(code2)
if not f2 then print("load2 error:", err) os.exit(1) end
print("test2 load ok, dumping...")
local ok, r = pcall(string.dump, f2, true)
if ok then print("test2 dump ok, size:", #r) else print("test2 dump error:", r) end
print("all tests done")
