-- nest_check.lua - 两轮嵌套混淆测试桩 (被 regress/run_matrix.py 的 nest 子命令调用)
-- arg[1] = 源码文件(第一轮输入) | arg[2] = 模块逗号列表("NONE"=不混淆) | arg[3] = seed
--
-- 流程: 源码 -> load/dump/undump -> 应用模块链(round1) -> dump(bc1)
--       -> undump(bc1) -> 再应用模块链(round2) -> dump(bc2) -> load 运行 -> print 输出
-- 输出协议(写入 stdout, run_matrix.py 判定):
--   NEST_GEN_ERR  <msg>   混淆阶段错误
--   NEST_LOAD_ERR <msg>   字节码加载错误
--   NEST_TIMEOUT          运行超时
--   NEST_RUN_ERR  <msg>   运行期 Lua 错误
--   其它输出           视为正常输出, 与基线(NONE 直接运行)对比
local luac = require("luac")

local function read_file(p)
  local f = assert(io.open(p, "rb")); local d = f:read("*a"); f:close(); return d
end

-- VM 生成类模块在嵌套场景无意义(产物是 VM 源码而非字节码), 且调用签名特殊, 跳过
local SKIP_VM = {
  vm_embed_c = true, vm_reg_shuffle_c = true,
  vm_const_shuffle_c = true, vm_dispatch_shuffle_c = true,
}

local src = read_file(arg[1])
local seed = tonumber(arg[3] or "0")
if seed and seed ~= 0 then luac.srand(seed) end

local mods = {}
if arg[2] and arg[2] ~= "NONE" then
  for m in arg[2]:gmatch("[^,]+") do
    if not SKIP_VM[m] then mods[#mods + 1] = m end
  end
end

local function apply_mods(proto)
  for _, m in ipairs(mods) do
    local ok, r = pcall(luac[m], proto)
    if not ok then return false, "module " .. m .. ": " .. tostring(r) end
    local hok, hv = pcall(luac.heapcheck_c)
    if hok and hv == false then return false, "HEAP_CORRUPT_AFTER " .. m end
    local rok, rmsg = pcall(luac.regcheck_c)
    if rok and type(rmsg) == "string" and #rmsg > 0 then
      return false, m .. " " .. rmsg
    end
  end
  return true, nil
end

-- 第一轮: 源码 -> bc1
local ok1, f1 = pcall(load, src)
if not ok1 then print("NEST_GEN_ERR compile1: " .. tostring(f1)); return end
local ok2, bc1 = pcall(function() return string.dec(string.dump(f1, true)) end)
if not ok2 then print("NEST_GEN_ERR dump1: " .. tostring(bc1)); return end
local ok3, proto1 = pcall(luac.undump, bc1, false)
if not ok3 then print("NEST_GEN_ERR undump1: " .. tostring(proto1)); return end
local aok, aerr = apply_mods(proto1)
if not aok then print("NEST_GEN_ERR " .. tostring(aerr)); return end
local ok4, out1 = pcall(luac.dump, proto1)
if not ok4 then print("NEST_GEN_ERR dump2: " .. tostring(out1)); return end

-- 第二轮: bc1 -> bc2 (再应用一轮模块)
local ok5, proto2 = pcall(luac.undump, out1, false)
if not ok5 then print("NEST_LOAD_ERR undump2: " .. tostring(proto2)); return end
local bok, berr = apply_mods(proto2)
if not bok then print("NEST_GEN_ERR round2: " .. tostring(berr)); return end
local ok6, out2 = pcall(luac.dump, proto2)
if not ok6 then print("NEST_GEN_ERR dump3: " .. tostring(out2)); return end

-- 运行 bc2
local chunk, lerr = load(out2, "=obf")
if not chunk then print("NEST_LOAD_ERR load: " .. tostring(lerr)); return end

local lines = {}
local old_print = print
local function cap(...)
  local n = select("#", ...); local t = {}
  for i = 1, n do t[i] = tostring((select(i, ...))) end
  lines[#lines + 1] = table.concat(t, "\t")
end
local max_hooks = 500  -- 每次 hook 10 万指令, 500 次 = 5e7 指令预算
local hooks = 0
local function timeout_hook()
  hooks = hooks + 1
  if hooks > max_hooks then error("__RUN_TIMEOUT__", 0) end
end
local co = coroutine.create(chunk)
debug.sethook(co, timeout_hook, "", 100000)
print = cap
local rok, rerr = coroutine.resume(co)
debug.sethook(co)
print = old_print
if not rok then
  local es = tostring(rerr)
  if es:find("__RUN_TIMEOUT__") then print("NEST_TIMEOUT")
  else print("NEST_RUN_ERR " .. es) end
  return
end
print(table.concat(lines, "\n"))
