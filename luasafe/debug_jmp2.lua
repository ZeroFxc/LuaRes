local luac = require("luac")
local junk_jmp = require("junk_jmp")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

-- 只在第一个子函数注入少量 JMP
junk_jmp.inject(p.p[1], {count = 3, recursive = false})

print("p[1] after inject:")
for i = 1, #p.p[1].code do
    local inst = p.p[1].code[i]
    local op = inst % 64
    local bx = inst >> 14
    local sbx = bx - 131071
    local opname = op == 30 and "JMP" or op == 39 and "FORLOOP" or op == 40 and "FORPREP" or op == 38 and "RETURN" or tostring(op)
    print(string.format("  [%d] 0x%08X %s sbx=%d", i, inst, opname, sbx))
end

local out = luac.dump(p)
local ok, f = pcall(load, out)
print("\nLoad: " .. tostring(ok))
if ok then
    print("Execute:")
    f()
else
    print("Error: " .. tostring(f))
end
