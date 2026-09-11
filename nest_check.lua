-- nest_check.lua - apply the full (non-VM) module chain twice (obfuscate the obfuscated bytecode)
-- arg1=src arg2=mods arg3=seed ; prints captured output or error line prefixed NEST_
local luac=require("luac")
local function rf(p) local f=assert(io.open(p,"rb"));local d=f:read("*a");f:close();return d end
local src=rf(arg[1]); local seed=tonumber(arg[3]) or 1
local mods={}; for m in arg[2]:gmatch("[^,]+") do mods[#mods+1]=m end

local function chain(proto)
  for _,m in ipairs(mods) do
    local ok,e=pcall(luac[m],proto)
    if not ok then error("GEN "..m..": "..tostring(e),0) end
  end
  return luac.dump(proto)
end

luac.srand(seed)
local p1=luac.undump(string.dec(string.dump(assert(load(src)),true)),false)
local bc1=chain(p1)
luac.srand(seed+100000)
local p2=luac.undump(bc1,false)
local ok2,bc2=pcall(chain,p2)
if not ok2 then print("NEST_GEN_ERR "..tostring(bc2)); return end

local lines={}; local old=print
print=function(...) local n=select("#",...);local t={} for i=1,n do t[i]=tostring((select(i,...))) end lines[#lines+1]=table.concat(t,"\t") end
local hooks=0
debug.sethook(function() hooks=hooks+1; if hooks>300 then error("__T__",0) end end,"",100000)
local chunk,le=load(bc2,"=nest")
if not chunk then debug.sethook();print=old;print("NEST_LOAD_ERR "..tostring(le));return end
local rok,re=pcall(chunk)
debug.sethook();print=old
if not rok then
  local es=tostring(re); if es:find("__T__") then print("NEST_TIMEOUT") else print("NEST_RUN_ERR "..es) end
  return
end
print(table.concat(lines,"\n"))
