-- nest2.lua: two-round obfuscation with per-round module lists
-- arg1=src arg2=chain1 arg3=chain2 arg4=seed
local luac=require("luac")
local function rf(p) local f=assert(io.open(p,"rb"));local d=f:read("*a");f:close();return d end
local src=rf(arg[1]); local seed=tonumber(arg[4]) or 1
local function parse(s) local t={} for m in s:gmatch("[^,]+") do t[#t+1]=m end return t end
local c1,c2=parse(arg[2] or ""),parse(arg[3] or "")
local function chain(proto,mods)
  for _,m in ipairs(mods) do
    local ok,e=pcall(luac[m],proto)
    if not ok then error("GEN "..m..": "..tostring(e),0) end
  end
  return luac.dump(proto)
end
luac.srand(seed)
local p1=luac.undump(string.dec(string.dump(assert(load(src)),true)),false)
local bc1=chain(p1,c1)
luac.srand((seed+100000)%2000000)
local p2=luac.undump(bc1,false)
local ok2,bc2=pcall(chain,p2,c2)
if not ok2 then print("NEST_GEN_ERR "..tostring(bc2)); return end
local lines={}; local old=print
print=function(...) local n=select("#",...);local t={} for i=1,n do t[i]=tostring((select(i,...))) end lines[#lines+1]=table.concat(t,"\t") end
local hooks=0
debug.sethook(function() hooks=hooks+1; if hooks>400 then error("__T__",0) end end,"",100000)
local chunk,le=load(bc2,"=nest")
if not chunk then debug.sethook();print=old;print("NEST_LOAD_ERR "..tostring(le));return end
local rok,re=pcall(chunk)
debug.sethook();print=old
if not rok then
  local es=tostring(re); if es:find("__T__") then print("NEST_TIMEOUT") else print("NEST_RUN_ERR "..es) end
  return
end
print(table.concat(lines,"\n"))
