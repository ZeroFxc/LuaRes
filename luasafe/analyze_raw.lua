local luac = require("luac")

local f = io.open("E:/LuaRes/fangtd.lua", "rb")
local data = f:read("*a")
f:close()

local p = luac.undump(data, false)

print("=== Main function ===")
print("numparams=" .. p.numparams)
print("is_vararg=" .. p.is_vararg)
print("maxstacksize=" .. p.maxstacksize)
print("linedefined=" .. p.linedefined)
print("lastlinedefined=" .. p.lastlinedefined)
print("sizecode=" .. #p.code)
print("sizek=" .. #p.k)
print("sizep=" .. #p.p)
print("sizeupvalues=" .. p.sizeupvalues)
print("sizelineinfo=" .. #p.lineinfo)
print("sizelocvars=" .. #p.locvars)

-- 检查 main 的 upvalues
print("\n=== Main upvalues (first 5) ===")
for i = 1, math.min(5, #p.upvalues) do
    local uv = p.upvalues[i]
    print(string.format("  [%d] instack=%d idx=%d name='%s'", i, uv.instack, uv.idx, uv.name or ""))
end

-- 检查 main 的指令操作码
print("\n=== Main instruction opcodes ===")
local opcount = {}
for i = 1, #p.code do
    local op = p.code[i] % 64
    opcount[op] = (opcount[op] or 0) + 1
end
for op, count in pairs(opcount) do
    print(string.format("  OP_%d: %d", op, count))
end

-- 检查 main 的常量
print("\n=== Main constants ===")
for i = 1, #p.k do
    local v = p.k[i]
    print(string.format("  [%d] type=%s value=%s", i, type(v), tostring(v):sub(1, 60)))
end

-- 检查前 3 个子函数
print("\n=== First 3 sub-functions ===")
for i = 1, math.min(3, #p.p) do
    local sub = p.p[i]
    print(string.format("\n--- p[%d] ---", i))
    print("  numparams=" .. sub.numparams)
    print("  is_vararg=" .. sub.is_vararg)
    print("  maxstacksize=" .. sub.maxstacksize)
    print("  sizecode=" .. #sub.code)
    print("  sizek=" .. #sub.k)
    print("  sizep=" .. #sub.p)
    print("  sizeupvalues=" .. sub.sizeupvalues)
    print("  sizelineinfo=" .. #sub.lineinfo)
    print("  lineinfo match: " .. tostring(#sub.lineinfo == #sub.code))
end

-- 全局统计异常
print("\n=== Global anomaly scan ===")
local stats = {total=0, bad_upval=0, bad_lineinfo=0, bad_opcode=0, bad_maxstack=0, bad_numparams=0}
local function scan(pp)
    stats.total = stats.total + 1
    if pp.sizeupvalues > 50 then stats.bad_upval = stats.bad_upval + 1 end
    if #pp.lineinfo ~= #pp.code then stats.bad_lineinfo = stats.bad_lineinfo + 1 end
    if pp.maxstacksize > 100 then stats.bad_maxstack = stats.bad_maxstack + 1 end
    if pp.numparams > 100 then stats.bad_numparams = stats.bad_numparams + 1 end
    for i = 1, #pp.code do
        local op = pp.code[i] % 64
        if op > 46 then stats.bad_opcode = stats.bad_opcode + 1 end
    end
    for i = 1, #pp.p do scan(pp.p[i]) end
end
scan(p)
for k, v in pairs(stats) do print("  " .. k .. "=" .. v) end
