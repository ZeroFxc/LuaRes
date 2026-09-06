local luac = require("luac")
local antidec = require("antidec")

-- 测试脚本
local test_func = function()
    local function add(a, b) return a + b end
    local function mul(a, b) return a * b end
    local t = {x = 10, y = 20}
    local sum = add(t.x, t.y)
    local prod = mul(t.x, t.y)
    return sum, prod, string.format("sum=%d, prod=%d", sum, prod)
end

local bc = string.dec(string.dump(test_func))
print("Original size: " .. #bc)

local p = luac.undump(bc, false)
print("Original main: numparams=" .. p.numparams .. " maxstack=" .. p.maxstacksize .. " lineinfo=" .. #p.lineinfo)

-- 应用 anti-td 保护
antidec.protect(p, {junk_constants = true})
print("Protected main: numparams=" .. p.numparams .. " maxstack=" .. p.maxstacksize .. " lineinfo=" .. #p.lineinfo .. " sizek=" .. #p.k)

local out = luac.dump(p)
print("Protected size: " .. #out)

-- 验证可以正常加载和执行
local ok, func = pcall(load, out)
print("Load: " .. tostring(ok))
if ok then
    local a, b, c = func()
    print("Execute: " .. tostring(a) .. ", " .. tostring(b) .. ", " .. tostring(c))
    print("Result correct: " .. tostring(a == 30 and b == 200 and c == "sum=30, prod=200"))
else
    print("  Error: " .. tostring(func))
end

-- 验证 re-undump
local p2 = luac.undump(out, false)
print("Re-undump: numparams=" .. p2.numparams .. " maxstack=" .. p2.maxstacksize .. " lineinfo=" .. #p2.lineinfo)
