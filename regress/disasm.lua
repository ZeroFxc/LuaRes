-- disasm.lua: 编译->按序模块->反汇编打印
-- arg1=源码 arg2=模块逗号列表 arg3=seed
local luac = require("luac")
local function readf(p) local f=assert(io.open(p,"rb")); local d=f:read("*a"); f:close(); return d end
local OPN = luac.OPCODE_NAMES
local function opn(op) return OPN[op+1] or ("OP"..op) end
local src = readf(arg[1])
if arg[3] then luac.srand(tonumber(arg[3])) end
local f=assert(load(src))
local p=luac.undump(string.dec(string.dump(f,true)),false)
if arg[2] and arg[2]~="NONE" then
  for m in arg[2]:gmatch("[^,]+") do
    local ok,e=pcall(luac[m],p); io.stderr:write(string.format("apply %s -> %s\n",m,tostring(ok and e or e)))
  end
end
local function dis(proto,depth,name)
  local pref=string.rep("  ",depth)
  io.write(string.format("%s=== %s sizecode=%s sizek=%s maxstack=%s\n",pref,name,proto.sizecode,proto.sizek,proto.maxstacksize))
  -- 常量
  for i=1,(proto.sizek or 0) do
    local k=proto.k[i]
    io.write(string.format("%s  K[%d]=%s(%s)\n",pref,i-1,type(k),tostring(k):sub(1,30)))
  end
  local code=proto.code
  for i=1,proto.sizecode do
    local ins=code[i]
    local op=ins%64; local a=math.floor(ins/64)%256
    local c=math.floor(ins/16384)%512; local b=math.floor(ins/8388608)%512
    local bx=math.floor(ins/16384)%262144; local sbx=bx-131071
    local extra=""
    if op==1 or op==2 then extra="A="..a.." Bx="..bx
    elseif op==30 or op==39 or op==40 or op==42 then extra="A="..a.." sBx="..sbx.." ->"..(i-1+1+sbx)
    else extra=string.format("A=%d B=%d C=%d",a,b,c) end
    io.write(string.format("%s  [%03d] %-9s %s\n",pref,i-1,opn(op),extra))
  end
  if proto.p then for i=1,proto.sizep do dis(proto.p[i],depth+1,"child"..i) end end
end
dis(p,0,"main")
