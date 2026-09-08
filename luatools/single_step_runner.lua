-- single_step_runner.lua - Lua 5.3 字节码单指令运行器（可靠版）
-- 用途：反汇编字节码、逐条查看指令、对比混淆前后的执行结果和轨迹
--
-- 设计：
--   1. Disassembler - 用 luac.undump 解析字节码，反汇编每条指令
--   2. Runner - 用标准 Lua VM 执行字节码，捕获输出
--   3. Comparator - 对比两个字节码的执行结果
--   4. Tracer - 用 debug.sethook 记录函数调用轨迹

local luac = require("luac")

local OP_NAMES = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL",
  "GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE",
  "NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV",
  "BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT",
  "JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN",
  "FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}

-- ============================================================
-- 反汇编器
-- ============================================================

local Disasm = {}
Disasm.__index = Disasm

function Disasm.new(bytecode)
  local proto = luac.undump(bytecode, false)
  return setmetatable({proto = proto, pc = 1}, Disasm)
end

function Disasm.decode(ins)
  if type(ins) == "table" then
    -- Some versions store code as tables with decoded fields
    return ins.op or ins.opcode or 0, ins.a or 0, ins.b or 0, ins.c or 0, ins.bx or 0, ins.sbx or 0
  end
  local op = ins % 64
  local a = math.floor(ins / 64) % 256
  local c = math.floor(ins / 16384) % 512
  local b = math.floor(ins / 8388608) % 512
  local bx = math.floor(ins / 64) % 262144
  local sbx = bx - 131072
  return op, a, b, c, bx, sbx
end

function Disasm:fmt(ins)
  local op, a, b, c, bx, sbx = Disasm.decode(ins)
  local name = OP_NAMES[op+1] or ("op"..op)
  -- RK operands
  local function rk(v)
    if v >= 256 then return "k(" .. tostring(self.proto.k and self.proto.k[v-255] or "?") .. ")"
    else return "R" .. v end
  end
  if op == 1 or op == 2 then  -- LOADK/LOADKX
    return string.format("%-10s R%d = k(%s)", name, a, tostring(self.proto.k and self.proto.k[bx+1] or "?"))
  elseif op == 30 then  -- JMP
    return string.format("%-10s pc+%d (-> %d)", name, sbx, self.pc - 1 + sbx)
  elseif op == 31 or op == 32 or op == 33 then  -- EQ/LT/LE
    return string.format("%-10s if %s %s %s then skip JMP", name, rk(b), (op==31 and "==") or (op==32 and "<") or "<=", rk(c))
  elseif op == 36 or op == 37 then  -- CALL/TAILCALL
    return string.format("%-10s R%d(...), %d args, %d rets", name, a, b-1, c-1)
  elseif op == 38 then  -- RETURN
    return string.format("%-10s return R%d..R%d (%d vals)", name, a, a+b-2, b-1)
  elseif op == 39 or op == 40 then  -- FORLOOP/FORPREP
    return string.format("%-10s R%d, pc+%d", name, a, sbx)
  elseif op == 44 then  -- CLOSURE
    return string.format("%-10s R%d = proto[%d]", name, a, bx)
  elseif op == 43 then  -- SETLIST
    return string.format("%-10s R%d[%d..] = R%d..R%d", name, a, b==0 and "EXTRA" or b, a+1, a+b)
  elseif op == 45 then  -- VARARG
    return string.format("%-10s R%d.. = ... (%d)", name, a, b-1)
  elseif op == 6 then  -- GETTABUP
    return string.format("%-10s R%d = Upval[%d][%s]", name, a, b, rk(c))
  elseif op == 8 then  -- SETTABUP
    return string.format("%-10s Upval[%d][%s] = R%d", name, b, rk(c), a)
  elseif op == 7 then  -- GETTABLE
    return string.format("%-10s R%d = R%d[%s]", name, a, b, rk(c))
  elseif op == 10 then  -- SETTABLE
    return string.format("%-10s R%d[%s] = %s", name, a, rk(b), rk(c))
  elseif op >= 13 and op <= 24 then  -- arithmetic/bitwise
    local ops = {[13]="+",[14]="-",[15]="*",[16]="%",[17]="^",[18]="/",[19]="//",[20]="&",[21]="|",[22]="~",[23]="<<",[24]=">>"}
    return string.format("%-10s R%d = %s %s %s", name, a, rk(b), ops[op] or "?", rk(c))
  elseif op == 25 then return string.format("%-10s R%d = -%s", name, a, rk(b))
  elseif op == 26 then return string.format("%-10s R%d = ~%s", name, a, rk(b))
  elseif op == 27 then return string.format("%-10s R%d = not %s", name, a, rk(b))
  elseif op == 28 then return string.format("%-10s R%d = #%s", name, a, rk(b))
  elseif op == 29 then return string.format("%-10s R%d = R%d....R%d", name, a, b, c)
  elseif op == 0 then return string.format("%-10s R%d = R%d", name, a, b)
  elseif op == 5 then return string.format("%-10s R%d = Upval[%d]", name, a, b)
  elseif op == 9 then return string.format("%-10s Upval[%d] = R%d", name, b, a)
  elseif op == 12 then return string.format("%-10s R%d = {}", name, a)
  elseif op == 3 then return string.format("%-10s R%d = %s%s", name, a, b~=0 and "true" or "false", c~=0 and " (skip next)" or "")
  elseif op == 4 then return string.format("%-10s R%d..R%d = nil", name, a, b)
  elseif op == 34 then return string.format("%-10s if not R%d == %s then skip JMP", name, a, c~=0)
  elseif op == 35 then return string.format("%-10s if not R%d == %s then skip JMP else R%d=R%d", name, b, c~=0, a, b)
  elseif op == 13 then return string.format("%-10s R%d = %s + %s", name, a, rk(b), rk(c))
  else return string.format("%-10s A=%d B=%d C=%d", name, a, b, c)
  end
end

function Disasm:disassemble(proto, depth)
  depth = depth or 0
  local indent = string.rep("  ", depth)
  local lines = {}

  table.insert(lines, indent .. string.format("=== Proto %s (sizecode=%d, sizek=%d, sizep=%d, numparams=%d, maxstack=%d) ===",
    depth == 0 and "main" or ("[" .. (depth-1) .. "]"),
    proto.sizecode, proto.sizek, proto.sizep, proto.numparams, proto.maxstacksize))

  -- Constants
  if proto.sizek > 0 then
    table.insert(lines, indent .. "  Constants:")
    for i = 1, proto.sizek do
      local k = proto.k[i]
      local ks = type(k) == "string" and '"' .. k:sub(1, 40) .. '"' or tostring(k)
      table.insert(lines, indent .. string.format("    k[%d] = %s (%s)", i-1, ks, type(k)))
    end
  end

  -- Instructions
  table.insert(lines, indent .. "  Instructions:")
  for i = 1, proto.sizecode do
    self.pc = i
    local ins = proto.code[i]
    table.insert(lines, indent .. string.format("    [%03d] %s", i-1, self:fmt(ins)))
  end

  -- Sub-protos
  if proto.p then
    for i = 1, proto.sizep do
      local sub_lines = self:disassemble(proto.p[i], depth + 1)
      for _, l in ipairs(sub_lines) do table.insert(lines, l) end
    end
  end

  return lines
end

function Disasm:dump()
  local lines = self:disassemble(self.proto, 0)
  return table.concat(lines, "\n")
end

-- ============================================================
-- 执行器（用标准 Lua VM）
-- ============================================================

local function run_bytecode(bytecode, env)
  -- Capture print output
  local original_print = print
  local output = {}
  local captured_print = function(...)
    local args = {...}
    local parts = {}
    for i = 1, select('#', ...) do
      parts[i] = tostring(args[i])
    end
    table.insert(output, table.concat(parts, "\t"))
  end

  -- Set up environment
  local func_env = env or {}
  func_env.print = captured_print
  func_env.tostring = tostring
  func_env.tonumber = tonumber
  func_env.type = type
  func_env.pairs = pairs
  func_env.ipairs = ipairs
  func_env.select = select
  func_env.error = error
  func_env.pcall = pcall
  func_env.math = math
  func_env.string = string
  func_env.table = table
  func_env._VERSION = _VERSION
  func_env._G = func_env

  -- Load and run bytecode
  local ok, err = pcall(function()
    local func = load(bytecode, "=obfuscated", "b", func_env)
    if not func then error("load failed") end
    func()
  end)

  if not ok then
    return nil, tostring(err), output
  end
  return output, nil, output
end

-- ============================================================
-- 对比器
-- ============================================================

local function compare(bc1, bc2, label1, label2)
  label1 = label1 or "original"
  label2 = label2 or "obfuscated"

  local out1, err1 = run_bytecode(bc1)
  local out2, err2 = run_bytecode(bc2)

  print("=== 执行结果对比 ===")
  print(string.format("[%s] %s: %d 行输出", label1, err1 and "错误("..err1..")" or "成功", out1 and #out1 or 0))
  print(string.format("[%s] %s: %d 行输出", label2, err2 and "错误("..err2..")" or "成功", out2 and #out2 or 0))

  if err1 or err2 then
    print("  *** 有执行错误，无法对比 ***")
    return false, out1, out2
  end

  local max_lines = math.max(#out1, #out2)
  local diffs = 0
  for i = 1, max_lines do
    local l1 = out1[i] or "(无)"
    local l2 = out2[i] or "(无)"
    if l1 ~= l2 then
      diffs = diffs + 1
      if diffs <= 10 then
        print(string.format("  行 %d 不同:", i))
        print(string.format("    [%s] %s", label1, l1))
        print(string.format("    [%s] %s", label2, l2))
      end
    end
  end

  if diffs == 0 then
    print("  *** 输出完全一致，混淆正确 ***")
  else
    print(string.format("  *** 发现 %d 处差异 ***", diffs))
  end

  return diffs == 0, out1, out2
end

-- ============================================================
-- Opcode 统计
-- ============================================================

local function opcode_stats(bytecode)
  local proto = luac.undump(bytecode, false)
  local stats = {total = 0, by_op = {}, by_proto = {}}

  local function count(p, name)
    local proto_stats = {total = p.sizecode, by_op = {}}
    for i = 1, p.sizecode do
      local op = p.code[i] % 64
      local opname = OP_NAMES[op+1] or ("op"..op)
      stats.by_op[opname] = (stats.by_op[opname] or 0) + 1
      proto_stats.by_op[opname] = (proto_stats.by_op[opname] or 0) + 1
      stats.total = stats.total + 1
    end
    table.insert(stats.by_proto, {name = name, stats = proto_stats})
    if p.p then
      for i = 1, p.sizep do
        count(p.p[i], name .. ".p" .. (i-1))
      end
    end
  end

  count(proto, "main")
  return stats
end

local function compare_opcode_stats(bc1, bc2, label1, label2)
  label1 = label1 or "original"
  label2 = label2 or "obfuscated"
  local s1 = opcode_stats(bc1)
  local s2 = opcode_stats(bc2)

  print("=== Opcode 统计对比 ===")
  print(string.format("[%s] 总指令: %d", label1, s1.total))
  print(string.format("[%s] 总指令: %d", label2, s2.total))
  print(string.format("指令数变化: %+d (%.1f%%)", s2.total - s1.total, (s2.total - s1.total) / s1.total * 100))

  print("\n各 opcode 变化:")
  local all_ops = {}
  for op in pairs(s1.by_op) do all_ops[op] = true end
  for op in pairs(s2.by_op) do all_ops[op] = true end
  local sorted = {}
  for op in pairs(all_ops) do table.insert(sorted, op) end
  table.sort(sorted, function(a,b) return math.abs((s2.by_op[b] or 0) - (s1.by_op[b] or 0)) < math.abs((s2.by_op[a] or 0) - (s1.by_op[a] or 0)) end)

  for _, op in ipairs(sorted) do
    local c1 = s1.by_op[op] or 0
    local c2 = s2.by_op[op] or 0
    if c1 ~= c2 then
      local color = c2 > c1 and "+" or ""
      print(string.format("  %-12s %4d -> %4d (%s%d)", op, c1, c2, color, c2 - c1))
    end
  end

  return s1, s2
end

-- ============================================================
-- 模块组合测试器
-- ============================================================

local function test_module_combo(bytecode, modules, test_name)
  -- This is a placeholder - actual module application happens in the WASM/web environment
  -- In native Lua, use luac library functions directly
  print(string.format("=== 测试: %s ===", test_name or "unknown"))
  print(string.format("  模块: %s", table.concat(modules, ", ")))
  print("  (在 WASM 环境中应用模块后调用 compare 进行验证)")
end

return {
  Disasm = Disasm,
  disassemble = function(bc) return Disasm.new(bc):dump() end,
  run = run_bytecode,
  compare = compare,
  opcode_stats = opcode_stats,
  compare_opcode_stats = compare_opcode_stats,
  test_module_combo = test_module_combo,
  OP_NAMES = OP_NAMES,
}
