local luac = require("luac")
local f = io.open("E:/LuaRes/fangtd_fixed.lua", "rb")
local data = f:read("*a")
f:close()

local p = luac.undump(data, false)
print("=== Fixed main function header ===")
print("numparams: " .. p.numparams)
print("is_vararg: " .. p.is_vararg)
print("maxstacksize: " .. p.maxstacksize)
print("linedefined: " .. p.linedefined)
print("lastlinedefined: " .. p.lastlinedefined)
print("sizecode: " .. #p.code)
print("sizek: " .. #p.k)
print("sizep: " .. #p.p)
print("sizeupvalues: " .. p.sizeupvalues)
print("sizelineinfo: " .. #p.lineinfo)
print("lineinfo matches code: " .. tostring(#p.lineinfo == #p.code))

-- 检查前几个子函数
print("\n=== First 3 sub-functions ===")
for i = 1, math.min(3, #p.p) do
    local sub = p.p[i]
    print(string.format("  p[%d]: numparams=%d is_vararg=%d maxstack=%d sizecode=%d lineinfo=%d match=%s",
        i, sub.numparams, sub.is_vararg, sub.maxstacksize, #sub.code, #sub.lineinfo,
        tostring(#sub.lineinfo == #sub.code)))
end

-- 统计所有函数的 lineinfo 匹配情况
local total = 0
local mismatch = 0
local function check(p)
    total = total + 1
    if #p.lineinfo ~= #p.code then mismatch = mismatch + 1 end
    for i = 1, #p.p do check(p.p[i]) end
end
check(p)
print(string.format("\n=== Total: %d functions, %d lineinfo mismatches ===", total, mismatch))

-- 测试执行
print("\n=== Load test ===")
local ok, err = pcall(load, data)
print("load: " .. tostring(ok))
if not ok then print("  error: " .. tostring(err)) end
