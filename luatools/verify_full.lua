-- verify_full.lua - 全面字节码对比工具：读出所有变更（指令/常量池/子proto/调试信息/upvalue）
local luac = require("luac")

local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL",
  "GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE",
  "NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV",
  "BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT",
  "JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN",
  "FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}

local function decode_ins(ins)
  local op = ins % 64
  local a = math.floor(ins / 64) % 256
  local c = math.floor(ins / 16384) % 512
  local b = math.floor(ins / 8388608) % 512
  local bx = math.floor(ins / 64) % 262144
  local sbx = bx - 131072
  return op, a, b, c, bx, sbx
end

local function fmt_ins(ins)
  local op, a, b, c, bx, sbx = decode_ins(ins)
  local name = opnames[op+1] or ("op"..op)
  if op == 1 or op == 2 then -- LOADK/LOADKX
    return string.format("%-10s A=%d Bx=%d", name, a, bx)
  elseif op == 27 or op == 33 or op == 34 or op == 35 then -- JMP/EQ/LT/LE
    return string.format("%-10s A=%d B=%d C=%d sbx=%d", name, a, b, c, sbx)
  elseif op == 37 or op == 38 then -- FORLOOP/FORPREP
    return string.format("%-10s A=%d sbx=%d", name, a, sbx)
  elseif op == 36 or op == 39 then -- CLOSURE/TFORLOOP
    return string.format("%-10s A=%d Bx=%d", name, a, bx)
  else
    return string.format("%-10s A=%d B=%d C=%d", name, a, b, c)
  end
end

-- 递归收集 proto 信息
local function collect_proto(p, path, result)
  result = result or {}
  local info = {
    path = path,
    sizecode = p.sizecode,
    sizek = p.sizek,
    sizep = p.sizep,
    numparams = p.numparams,
    is_vararg = p.is_vararg,
    maxstacksize = p.maxstacksize,
    sizeupvalues = p.sizeupvalues,
    code = {},
    k = {},
    k_types = {},
    upvalues = {},
    locvars = {},
    lineinfo = {},
  }
  -- 指令
  for i = 1, p.sizecode do
    info.code[i] = p.code[i]
  end
  -- 常量池
  if p.k then
    for i = 1, p.sizek do
      local v = p.k[i]
      info.k[i] = v
      info.k_types[i] = type(v)
    end
  end
  -- upvalues
  if p.upvalues then
    for i = 1, p.sizeupvalues do
      info.upvalues[i] = p.upvalues[i]
    end
  end
  -- 调试信息
  if p.locvars then
    for i = 1, #p.locvars do
      local lv = p.locvars[i]
      info.locvars[i] = {name=lv.varname, startpc=lv.startpc, endpc=lv.endpc}
    end
  end
  if p.lineinfo then
    for i = 1, #p.lineinfo do
      info.lineinfo[i] = p.lineinfo[i]
    end
  end
  table.insert(result, info)
  -- 子 proto
  if p.p then
    for i = 1, p.sizep do
      collect_proto(p.p[i], path .. "." .. (i-1), result)
    end
  end
  return result
end

local function compare_protos(before, after, label)
  print("\n" .. string.rep("=", 60))
  print("=== " .. label .. " ===")
  print(string.rep("=", 60))

  local b_protos = collect_proto(before, "main")
  local a_protos = collect_proto(after, "main")

  print(string.format("\nProto 数量: %d -> %d", #b_protos, #a_protos))

  local max_n = math.max(#b_protos, #a_protos)
  for idx = 1, max_n do
    local b = b_protos[idx]
    local a = a_protos[idx]
    local path = (a or b).path
    print(string.format("\n--- Proto [%s] ---", path))

    if not b then
      print("  *** 新增 proto ***")
      b = {sizecode=0, sizek=0, sizep=0, code={}, k={}, locvars={}, lineinfo={}, upvalues={}}
    end
    if not a then
      print("  *** proto 被删除 ***")
      goto continue
    end

    -- 基本属性
    local attrs = {"sizecode","sizek","sizep","numparams","is_vararg","maxstacksize","sizeupvalues"}
    for _, attr in ipairs(attrs) do
      if b[attr] ~= a[attr] then
        print(string.format("  %s: %s -> %s", attr, tostring(b[attr]), tostring(a[attr])))
      end
    end

    -- 指令变化
    if b.sizecode ~= a.sizecode then
      print(string.format("  指令数: %d -> %d (%+d)", b.sizecode, a.sizecode, a.sizecode - b.sizecode))
    end
    -- 逐条对比指令（最多显示前 20 条差异）
    local ins_diff = 0
    local max_ins = math.max(b.sizecode, a.sizecode)
    for i = 1, max_ins do
      local bi = b.code[i]
      local ai = a.code[i]
      if bi ~= ai then
        ins_diff = ins_diff + 1
        if ins_diff <= 10 then
          local bs = bi and fmt_ins(bi) or "(无)"
          local as_ = ai and fmt_ins(ai) or "(无)"
          print(string.format("  [%d] %s  =>  %s", i-1, bs, as_))
        end
      end
    end
    if ins_diff > 10 then
      print(string.format("  ... 共 %d 条指令有差异", ins_diff))
    end
    if b.sizecode == a.sizecode and ins_diff == 0 then
      print("  指令: 完全相同")
    end

    -- 常量池变化
    if b.sizek ~= a.sizek then
      print(string.format("  常量池大小: %d -> %d", b.sizek, a.sizek))
    end
    local max_k = math.max(b.sizek, a.sizek)
    local k_diff = 0
    for i = 1, max_k do
      local bv = b.k[i]
      local av = a.k[i]
      local bt = b.k_types[i] or "nil"
      local at = a.k_types[i] or "nil"
      if bt ~= at or tostring(bv) ~= tostring(av) then
        k_diff = k_diff + 1
        if k_diff <= 8 then
          local bstr = bv and (bt=="string" and '"'..tostring(bv):sub(1,30)..'"' or tostring(bv)) or "nil"
          local astr = av and (at=="string" and '"'..tostring(av):sub(1,30)..'"' or tostring(av)) or "nil"
          print(string.format("  k[%d]: %s(%s) -> %s(%s)", i-1, bstr, bt, astr, at))
        end
      end
    end
    if k_diff > 8 then
      print(string.format("  ... 共 %d 个常量有差异", k_diff))
    end
    if b.sizek == a.sizek and k_diff == 0 then
      print("  常量池: 完全相同")
    end

    -- 调试信息: locvars
    local bl = #b.locvars
    local al = #a.locvars
    if bl ~= al then
      print(string.format("  locvar 数量: %d -> %d", bl, al))
    end
    local max_lv = math.max(bl, al)
    local lv_diff = 0
    for i = 1, max_lv do
      local bv = b.locvars[i]
      local av = a.locvars[i]
      local bname = bv and bv.name or "nil"
      local aname = av and av.name or "nil"
      if bname ~= aname or (bv and av and (bv.startpc ~= av.startpc or bv.endpc ~= av.endpc)) then
        lv_diff = lv_diff + 1
        if lv_diff <= 8 then
          local bs = bv and string.format("%s[%d-%d]", bv.name, bv.startpc, bv.endpc) or "nil"
          local as_ = av and string.format("%s[%d-%d]", av.name, av.startpc, av.endpc) or "nil"
          print(string.format("  locvar[%d]: %s -> %s", i-1, bs, as_))
        end
      end
    end
    if lv_diff > 8 then
      print(string.format("  ... 共 %d 个 locvar 有差异", lv_diff))
    end
    if bl == al and lv_diff == 0 then
      print("  locvars: 完全相同")
    end

    -- 调试信息: lineinfo
    local bli = #b.lineinfo
    local ali = #a.lineinfo
    if bli ~= ali then
      print(string.format("  lineinfo 数量: %d -> %d", bli, ali))
    end
    if bli == ali and bli > 0 then
      local li_same = true
      for i = 1, math.min(bli, 20) do
        if b.lineinfo[i] ~= a.lineinfo[i] then li_same = false; break end
      end
      if not li_same then
        print("  lineinfo: 有变化（前20条抽样）")
        for i = 1, math.min(bli, 10) do
          if b.lineinfo[i] ~= a.lineinfo[i] then
            print(string.format("    lineinfo[%d]: %d -> %d", i-1, b.lineinfo[i], a.lineinfo[i]))
          end
        end
      else
        print("  lineinfo: 相同（前20条抽样）")
      end
    end

    -- upvalues
    local bu = #b.upvalues
    local au = #a.upvalues
    if bu ~= au then
      print(string.format("  upvalue 数量: %d -> %d", bu, au))
    end
    local max_uv = math.max(bu, au)
    for i = 1, max_uv do
      local bv = b.upvalues[i]
      local av = a.upvalues[i]
      if tostring(bv) ~= tostring(av) then
        print(string.format("  upvalue[%d]: %s -> %s", i-1, tostring(bv), tostring(av)))
      end
    end

    ::continue::
  end
end

-- 测试代码
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
  "str_encrypt_c",
  "str_split_c",
  "num_obfuscate_c",
  "bool_obfuscate_c",
  "table_obfuscate_c",
  "const_hide_c",
  "const_shuffle_c",
  "junk_jmp_c",
  "junk_loadk_c",
  "junk_move_c",
  "reg_shuffle_c",
  "proto_shuffle_c",
  "live_range_split_c",
  "indirect_call_c",
  "condition_split_c",
  "loop_restructure_c",
  "jmp_offset_c",
  "flatten_c",
  "flatten_enhance_c",
  "antidec_c",
  "debug_strip_c",
  "const_poison_c",
  "opaque_pred_c",
  "junk_op48_c",
  "pure_junk_c",
  "bytecode_encrypt_c",
}

for _, mod in ipairs(modules) do
  local p_before = compile_and_get_proto(test_code)
  local p_after = compile_and_get_proto(test_code)
  p_after = apply_module(p_after, mod, {count=15})
  if not p_after then goto continue end
  compare_protos(p_before, p_after, mod)
  ::continue::
end
