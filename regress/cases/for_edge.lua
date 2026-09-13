-- for_loop_unroll 通用展开正确性用例：覆盖正/负步长、浮点、变量边界、嵌套、break、空循环
local function line(...)
  local t = {...}
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring(t[i]) end
  print(table.concat(parts, ","))
end

-- 1) 正步长（含奇偶分支）
local s = 0
for i = 1, 5 do if i % 2 == 0 then s = s + i else s = s - i end end
line("pos", s)

-- 2) 第二个 for（验证连续两个 for 都被展开）
for j = 1, 3 do line("j", j) end

-- 3) 负步长
local r = {}
for k = 9, 1, -2 do r[#r + 1] = k end
line("neg", table.concat(r, "."))

-- 4) 浮点步长
local q = {}
for x = 0.0, 1.01, 0.25 do q[#q + 1] = string.format("%.2f", x) end
line("float", table.concat(q, "."))

-- 5) 变量边界 + 变量步长（非编译期常量）
local lo, hi, st = 3, 12, 3
local acc = 0
for v = lo, hi, st do acc = acc + v end
line("var", acc)

-- 6) 嵌套 for
local m = 0
for a = 1, 3 do for b = 1, 3 do m = m + a * b end end
line("nest", m)

-- 7) break
local bsum = 0
for z = 1, 100 do if z > 4 then break end bsum = bsum + z end
line("break", bsum)

-- 8) 空循环（start > limit，正步长，一次不执行）
local e = 99
for w = 10, 2 do e = e + 1 end
line("empty", e)

-- 9) 负步长空循环（start < limit，负步长，一次不执行）
local e2 = 7
for w = 2, 10, -1 do e2 = e2 + 1 end
line("emptyneg", e2)

line("done")
