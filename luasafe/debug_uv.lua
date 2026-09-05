local luac = require("luac")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

-- fib 是 p[3]
print("fib upvalues:")
for i = 1, #p.p[3].upvalues do
    local uv = p.p[3].upvalues[i]
    print(string.format("  upvalue[%d]: instack=%s idx=%s name=%s",
        i-1, tostring(uv.instack), tostring(uv.idx), tostring(uv.name)))
end

-- 看 main 函数中创建 fib 的 CLOSURE
print("\nmain code (looking for CLOSURE):")
for i = 1, #p.code do
    local inst = p.code[i]
    local op = inst % 64
    if op == 36 or op == 8 or op == 0 then
        local a = (inst >> 6) & 0xFF
        local bx = inst >> 14
        print(string.format("  [%d] op=%d A=%d Bx=%d", i, op, a, bx))
    end
end

-- 直接看 fib 的常量
print("\nfib constants:")
for i = 1, #p.p[3].k do
    local k = p.p[3].k[i]
    print(string.format("  k[%d]: type=%s value=%s", i-1, type(k), tostring(k)))
end
