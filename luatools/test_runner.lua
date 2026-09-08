-- test_runner.lua - 测试单指令运行器
local runner = require("single_step_runner")

-- 测试1: 简单算术
print("=== 测试1: 简单算术 ===")
local src1 = "local x = 10 + 5 * 2\nprint(x)"
local bc1 = string.dec(string.dump(load(src1), false))
local vm1 = runner.new(bc1)
local out1 = vm1:run()
print("输出: " .. table.concat(out1, ", "))
print("预期: 20")
print("结果: " .. (out1[1] == "20" and "通过" or "失败"))

-- 测试2: 字符串连接
print("\n=== 测试2: 字符串连接 ===")
local src2 = 'local a = "hello"\nlocal b = "world"\nprint(a .. " " .. b)'
local bc2 = string.dec(string.dump(load(src2), false))
local vm2 = runner.new(bc2)
local out2 = vm2:run()
print("输出: " .. table.concat(out2, ", "))
print("预期: hello world")
print("结果: " .. (out2[1] == "hello world" and "通过" or "失败"))

-- 测试3: 条件分支
print("\n=== 测试3: 条件分支 ===")
local src3 = "local x = 10\nif x > 5 then print('big') else print('small') end"
local bc3 = string.dec(string.dump(load(src3), false))
local vm3 = runner.new(bc3)
local out3 = vm3:run()
print("输出: " .. table.concat(out3, ", "))
print("预期: big")
print("结果: " .. (out3[1] == "big" and "通过" or "失败"))

-- 测试4: for 循环
print("\n=== 测试4: for 循环 ===")
local src4 = "for i = 1, 3 do print(i) end"
local bc4 = string.dec(string.dump(load(src4), false))
local vm4 = runner.new(bc4)
local out4 = vm4:run()
print("输出: " .. table.concat(out4, ", "))
print("预期: 1, 2, 3")
print("结果: " .. (#out4 == 3 and out4[1]=="1" and out4[2]=="2" and out4[3]=="3" and "通过" or "失败"))

-- 测试5: 表构造
print("\n=== 测试5: 表构造 ===")
local src5 = "local t = {10, 20, 30}\nprint(t[1], t[2], t[3])"
local bc5 = string.dec(string.dump(load(src5), false))
local vm5 = runner.new(bc5)
local out5 = vm5:run()
print("输出: " .. table.concat(out5, ", "))
print("预期: 10\t20\t30")
print("结果: " .. (out5[1] == "10\t20\t30" and "通过" or "失败"))

-- 测试6: 单步执行
print("\n=== 测试6: 单步执行 ===")
local src6 = "local x = 1 + 2\nprint(x)"
local bc6 = string.dec(string.dump(load(src6), false))
local vm6 = runner.new(bc6)
print("单步执行:")
for i = 1, 10 do
  if not vm6.running or vm6.pc > vm6.proto.sizecode then break end
  local ins = vm6.proto.code[vm6.pc]
  print("  " .. vm6:fmt_ins(ins))
  vm6:step()
end
print("输出: " .. table.concat(vm6.output, ", "))
print("结果: " .. (vm6.output[1] == "3" and "通过" or "失败"))

-- 测试7: 执行轨迹
print("\n=== 测试7: 执行轨迹 ===")
local src7 = "local x = 1\nx = x + 1\nprint(x)"
local bc7 = string.dec(string.dump(load(src7), false))
local vm7 = runner.new(bc7)
local trace = vm7:trace_run()
print("轨迹长度: " .. #trace)
for i, t in ipairs(trace) do
  print(string.format("  [%d] %s A=%d B=%d C=%d", t.pc, t.opname, t.a, t.b, t.c))
end
print("输出: " .. table.concat(vm7.output, ", "))

print("\n=== 全部测试完成 ===")
