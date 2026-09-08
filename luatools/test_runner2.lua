-- test_runner2.lua - 测试单指令运行器（可靠版）
local runner = require("single_step_runner")

-- 测试1: 反汇编
print("=== 测试1: 反汇编 ===")
local src1 = "local x = 10 + 5 * 2\nprint(x)"
local bc1 = string.dec(string.dump(load(src1), false))
local disasm = runner.disassemble(bc1)
print(disasm)

-- 测试2: 执行
print("\n=== 测试2: 执行 ===")
local out, err = runner.run(bc1)
print("输出: " .. table.concat(out or {}, ", "))
print("错误: " .. (err or "无"))
print("预期: 20")
print("结果: " .. (out and out[1] == "20" and "通过" or "失败"))

-- 测试3: 对比
print("\n=== 测试3: 对比（相同字节码） ===")
runner.compare(bc1, bc1, "original", "copy")

-- 测试4: 不同字节码对比
print("\n=== 测试4: 对比（不同字节码） ===")
local src2 = "local x = 100\nprint(x)"
local bc2 = string.dec(string.dump(load(src2), false))
runner.compare(bc1, bc2, "20", "100")

-- 测试5: Opcode 统计
print("\n=== 测试5: Opcode 统计 ===")
local src3 = "for i=1,3 do print(i) end\nlocal t={1,2,3}\nfor k,v in pairs(t) do print(k,v) end"
local bc3 = string.dec(string.dump(load(src3), false))
local stats = runner.opcode_stats(bc3)
print("总指令: " .. stats.total)
for op, cnt in pairs(stats.by_op) do
  print(string.format("  %-12s %d", op, cnt))
end

-- 测试6: 复杂脚本执行
print("\n=== 测试6: 复杂脚本执行 ===")
local src4 = [[
local function fib(n)
  if n <= 1 then return n end
  return fib(n-1) + fib(n-2)
end
for i = 1, 10 do
  print("fib(" .. i .. ") = " .. fib(i))
end
]]
local bc4 = string.dec(string.dump(load(src4), false))
local out4, err4 = runner.run(bc4)
if err4 then
  print("错误: " .. err4)
else
  print("输出 (" .. #out4 .. " 行):")
  for i, l in ipairs(out4) do
    print("  " .. l)
  end
end

print("\n=== 全部测试完成 ===")
