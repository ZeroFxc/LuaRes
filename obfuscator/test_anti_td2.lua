local luac = require("luac")
local antidec = require("antidec")

local test_func = function()
    local function add(a, b) return a + b end
    local t = {x = 10, y = 20}
    return add(t.x, t.y)
end

local bc = string.dec(string.dump(test_func))

-- 测试 1: 只 poison_header
local p1 = luac.undump(bc, false)
antidec.protect(p1, {poison_header=true, strip_lineinfo=false, junk_source=false, junk_constants=false})
local out1 = luac.dump(p1)
local ok1, f1 = pcall(load, out1)
print("1 poison_header only: load=" .. tostring(ok1))
if ok1 then
    local ok2, r = pcall(f1)
    print("  exec: " .. tostring(ok2) .. " result=" .. tostring(r))
end

-- 测试 2: 只 strip_lineinfo
local p2 = luac.undump(bc, false)
antidec.protect(p2, {poison_header=false, strip_lineinfo=true, junk_source=false, junk_constants=false})
local out2 = luac.dump(p2)
local ok3, f2 = pcall(load, out2)
print("2 strip_lineinfo only: load=" .. tostring(ok3))
if ok3 then
    local ok4, r = pcall(f2)
    print("  exec: " .. tostring(ok4) .. " result=" .. tostring(r))
end

-- 测试 3: 只 junk_source
local p3 = luac.undump(bc, false)
antidec.protect(p3, {poison_header=false, strip_lineinfo=false, junk_source=true, junk_constants=false})
local out3 = luac.dump(p3)
local ok5, f3 = pcall(load, out3)
print("3 junk_source only: load=" .. tostring(ok5))
if ok5 then
    local ok6, r = pcall(f3)
    print("  exec: " .. tostring(ok6) .. " result=" .. tostring(r))
end

-- 测试 4: 只 junk_constants
local p4 = luac.undump(bc, false)
antidec.protect(p4, {poison_header=false, strip_lineinfo=false, junk_source=false, junk_constants=true})
local out4 = luac.dump(p4)
local ok7, f4 = pcall(load, out4)
print("4 junk_constants only: load=" .. tostring(ok7))
if ok7 then
    local ok8, r = pcall(f4)
    print("  exec: " .. tostring(ok8) .. " result=" .. tostring(r))
end
