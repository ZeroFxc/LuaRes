-- verify_opcodes.lua - 验证模块是否真的改变了 opcode 分布
local luac = require("luac")

local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL",
  "GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE",
  "NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV",
  "BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT",
  "JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN",
  "FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}

local function count_ops(p, counts)
  counts = counts or {}
  for i = 1, p.sizecode do
    local op = p.code[i] % 64
    counts[op] = (counts[op] or 0) + 1
  end
  if p.p then
    for i = 1, p.sizep do
      count_ops(p.p[i], counts)
    end
  end
  return counts
end

local function total_insns(p)
  local n = p.sizecode
  if p.p then
    for i = 1, p.sizep do n = n + total_insns(p.p[i]) end
  end
  return n
end

local function dump_diff(before, after, label)
  print("\n=== " .. label .. " ===")
  print(string.format("  总指令: %d -> %d (变化 %+d)", before._total, after._total, after._total - before._total))
  local changed = {}
  for op = 0, 46 do
    local b = before[op] or 0
    local a = after[op] or 0
    if b ~= a then
      table.insert(changed, {op=op, name=opnames[op+1] or "op"..op, before=b, after=a, delta=a-b})
    end
  end
  table.sort(changed, function(x,y) return math.abs(x.delta) > math.abs(y.delta) end)
  for _, c in ipairs(changed) do
    print(string.format("  %-12s %4d -> %4d (%+d)", c.name, c.before, c.after, c.delta))
  end
  if #changed == 0 then
    print("  *** 无任何 opcode 变化！模块可能未生效 ***")
  end
end

-- 测试代码：覆盖各种结构
local test_code = [[
local x = 10
local y = "hello"
local t = {a=1, b=2, c=3}
if x > 5 then
    print(x)
    print(y)
else
    print("small")
end
for i = 1, 10 do
    t.a = t.a + i
end
local function f(a, b)
    return a + b * 2
end
print(f(3, 4))
print(t.a)
print(#y)
]]

local function compile_and_get_proto(src)
  local bc = string.dec(string.dump(load(src), true))
  return luac.undump(bc, false)
end

local function apply_module(proto, mod_name, opts)
  local mod = luac[mod_name]
  if not mod then
    print("  模块不存在: " .. mod_name)
    return nil
  end
  local ok, n = pcall(mod, proto, opts or {})
  if not ok then
    print("  模块执行失败: " .. mod_name .. " -> " .. tostring(n))
    return nil
  end
  print("  模块返回变更数: " .. tostring(n))
  return proto
end

local modules = {
  "operator_substitute_c",
  "debug_mutate_c",
  "call_rewrite_c",
  "upvalue_promote_c",
}

for _, mod in ipairs(modules) do
  -- before
  local p_before = compile_and_get_proto(test_code)
  local before = count_ops(p_before)
  before._total = total_insns(p_before)

  -- after
  local p_after = compile_and_get_proto(test_code)
  p_after = apply_module(p_after, mod, {count=20})
  if not p_after then goto continue end

  local after = count_ops(p_after)
  after._total = total_insns(p_after)

  dump_diff(before, after, mod)

  ::continue::
end
