local luac = require("luac")

local func = load("print('hello world')")
local bc = string.dec(string.dump(func))

-- 测试各种无效操作码
local invalid_ops = {47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63}

for _, op in ipairs(invalid_ops) do
    local p = luac.undump(bc, false)
    -- 构造一条该操作码的指令
    local a = 127
    local b = math.random(256, 511)
    local c = math.random(0, 200)
    local inst = (a << 6) | (b << 23) | (c << 14) | op
    table.insert(p.code, inst)
    p.lineinfo = {}

    local out = luac.dump(p)
    local ok, f = pcall(load, out)
    local result = ok and "OK" or "FAIL"
    if ok then
        -- 尝试执行
        local exec_ok, exec_err = pcall(f)
        result = exec_ok and "OK+EXEC" or "OK+CRASH: "..tostring(exec_err)
    else
        result = "LOAD_FAIL: "..tostring(f)
    end
    print(string.format("OP_%d: %s", op, result))
end

-- 测试连续多种无效操作码
print("\n=== Test multiple invalid ops in sequence ===")
local p = luac.undump(bc, false)
for i = 1, 50 do
    local op = invalid_ops[math.random(1, #invalid_ops)]
    local a = math.random(0, 255)
    local b = math.random(0, 511)
    local c = math.random(0, 511)
    local inst = (a << 6) | (b << 23) | (c << 14) | op
    table.insert(p.code, inst)
end
p.lineinfo = {}
local out = luac.dump(p)
local ok, f = pcall(load, out)
print("Load: " .. tostring(ok))
if ok then
    local exec_ok = pcall(f)
    print("Execute: " .. tostring(exec_ok))
end
