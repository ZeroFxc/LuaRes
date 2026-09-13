-- harness.lua - 原生混淆+执行测试桩 (被 luasafe/obf_test.exe 运行)
-- arg[1] = 源码文件
-- arg[2] = 模块逗号列表(已按执行顺序排好; "NONE"=不混淆基线)
-- arg[3] = opts JSON: rs_seed/cs_seed/ds_seed/ds_mode/luajit/run_hooks
-- arg[4] = 结果 JSON 输出文件
local luac = require("luac")

local function read_file(p)
  local f = assert(io.open(p,"rb")); local d=f:read("*a"); f:close(); return d
end
local function jesc(s)
  s = tostring(s)
  s = s:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\r","\\r"):gsub("\n","\\n"):gsub("\t","\\t")
  return s
end

local result = { stage="init", gen_ok=false, gen_err="", kind="",
  run_ok=false, run_err="", run_timeout=false, output="",
  size_in=0, size_out=0, module_changes={} }

local function write_result()
  local parts = {}
  parts[#parts+1] = ('"stage":"%s"'):format(jesc(result.stage))
  parts[#parts+1] = ('"gen_ok":%s'):format(result.gen_ok and "true" or "false")
  parts[#parts+1] = ('"gen_err":"%s"'):format(jesc(result.gen_err))
  parts[#parts+1] = ('"kind":"%s"'):format(jesc(result.kind))
  parts[#parts+1] = ('"run_ok":%s'):format(result.run_ok and "true" or "false")
  parts[#parts+1] = ('"run_err":"%s"'):format(jesc(result.run_err))
  parts[#parts+1] = ('"run_timeout":%s'):format(result.run_timeout and "true" or "false")
  parts[#parts+1] = ('"output":"%s"'):format(jesc(result.output))
  parts[#parts+1] = ('"size_in":%d'):format(result.size_in)
  parts[#parts+1] = ('"size_out":%d'):format(result.size_out)
  local mc = {}
  for k,v in pairs(result.module_changes) do mc[#mc+1] = ('"%s":%d'):format(jesc(k), v) end
  parts[#parts+1] = ('"module_changes":{%s}'):format(table.concat(mc,","))
  local out = io.open(arg[4],"wb")
  out:write("{"..table.concat(parts,",").."}")
  out:close()
end

-- 极简 opts 解析(只取需要的几个数字/布尔字段, 避免依赖 json 库)
local opts = {}
if arg[3] and arg[3] ~= "-" then
  for k,v in arg[3]:gmatch('"(%w+)":%s*(-?%d+)') do opts[k]=tonumber(v) end
end

local src = read_file(arg[1])
result.size_in = #src
if opts.seed then luac.srand(opts.seed) end

-- 编译 -> proto
local ok, proto = pcall(function()
  local f = assert(load(src))
  local bc = string.dec(string.dump(f, true))
  return luac.undump(bc, false)
end)
if not ok then
  result.stage="compile"; result.gen_err=tostring(proto); write_result(); return
end

-- 应用模块
local modules = arg[2]
local use_embed = false
if modules ~= "NONE" then
  local order = {}
  for m in modules:gmatch("[^,]+") do order[#order+1]=m end
  for _,m in ipairs(order) do
    if m == "vm_embed_c" then use_embed=true
    elseif m == "vm_reg_shuffle_c" then
      local r = luac[m](proto, {seed=opts.rs_seed or 0})
    elseif m == "vm_const_shuffle_c" then
      local r = luac[m](proto, {seed=opts.cs_seed or 0})
    elseif m == "vm_dispatch_shuffle_c" then
      local r = luac[m](proto, {seed=opts.ds_seed or 0, mode=opts.ds_mode or 0})
    else
      local rok, r = pcall(luac[m], proto)
      if not rok then
        result.stage="gen"; result.gen_err=m..": "..tostring(r); write_result(); return
      end
      result.module_changes[m] = tonumber(r) or 0
      local hok, hv = pcall(luac.heapcheck_c)
      if hok and hv == false then
        result.stage="gen"; result.gen_err="HEAP_CORRUPT_AFTER "..m; write_result(); return
      end
      local rok2, rmsg = pcall(luac.regcheck_c)
      if rok2 and type(rmsg)=="string" and #rmsg>0 then
        result.stage="gen"; result.gen_err=m.." "..rmsg; write_result(); return
      end
    end
  end
end

result.stage = "gen"
local artifact, kind
if use_embed then
  local eok, esrc = pcall(luac.vm_embed_c, proto, {luajit_compat = (opts.luajit==0) and false or true})
  if not eok then result.gen_err="vm_embed: "..tostring(esrc); write_result(); return end
  artifact = esrc; kind="lua"
else
  local dok, dbc = pcall(luac.dump, proto)
  if not dok then result.gen_err="dump: "..tostring(dbc); write_result(); return end
  artifact = dbc; kind="bc"
end
result.gen_ok=true; result.kind=kind; result.size_out=#artifact
result.stage="run"

-- 受控执行: 捕获 print, 指令计数软超时
local lines = {}
local old_print = print
local function cap(...)
  local n=select("#",...); local t={}
  for i=1,n do t[i]=tostring((select(i,...))) end
  lines[#lines+1]=table.concat(t,"\t")
end
local max_hooks = opts.run_hooks or 200   -- 每次 hook 100k 指令, 默认 200 -> 2e7 指令预算
local hooks = 0
local function timeout_hook()
  hooks = hooks + 1
  if hooks > max_hooks then error("__RUN_TIMEOUT__", 0) end
end

local chunk, lerr = (kind=="lua") and load(artifact, "=obf") or load(artifact, "=obf")
if not chunk then
  result.run_err="load: "..tostring(lerr); write_result(); return
end
print = cap
-- Run in a fresh coroutine (independent stack) so residues generation left on
-- this state's stack cannot be read as uninitialized registers by the chunk.
local co = coroutine.create(chunk)
debug.sethook(co, timeout_hook, "", 100000)
local rok, rerr = coroutine.resume(co)
debug.sethook(co)
print = old_print

result.output = table.concat(lines,"\n")
if rok then
  result.run_ok=true
else
  local es = tostring(rerr)
  if es:find("__RUN_TIMEOUT__") then result.run_timeout=true; result.run_err="RUN_TIMEOUT"
  else result.run_err=es end
end
write_result()
