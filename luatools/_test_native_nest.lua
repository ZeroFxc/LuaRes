-- 原生环境第二步嵌套测试
local luac = require("luac")

-- 测试脚本
local src = 'print("你好 Lua 5.3")\n'

-- 第一步：str_encrypt + vm_embed
local fn1 = load(src)
local bc1 = string.dec(string.dump(fn1, true))
local p1 = luac.undump(bc1, false)
luac.str_encrypt_c(p1)
local out1 = luac.vm_embed_c(p1, false)

-- 运行第一步输出
local fn_run1 = load(out1)
local old_print = print
local results1 = {}
print = function(...) results1[#results1+1] = table.concat({...}, "\t") end
fn_run1()
print = old_print
print("Pass1 output:", table.concat(results1, " | "))

-- 第二步：只用 vm_embed
local fn2 = load(out1)
local bc2 = string.dec(string.dump(fn2, true))
local p2 = luac.undump(bc2, false)
local out2 = luac.vm_embed_c(p2, false)

-- 运行第二步输出
local fn_run2 = load(out2)
local results2 = {}
print = function(...) results2[#results2+1] = table.concat({...}, "\t") end
fn_run2()
print = old_print
print("Pass2 output:", table.concat(results2, " | "))

-- 检查是否乱码
if results2[1] and results2[1]:find("你好") then
    print("PASS: 第二步输出正确")
else
    print("FAIL: 第二步输出乱码: " .. tostring(results2[1]))
end
