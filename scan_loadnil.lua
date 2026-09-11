local luac=require("luac")
local function rf(p) local f=assert(io.open(p,"rb"));local d=f:read("*a");f:close();return d end
local src=rf(arg[1]); local seed=tonumber(arg[3]) or 1
luac.srand(seed)
local proto=luac.undump(string.dec(string.dump(assert(load(src)),true)),false)
for m in arg[2]:gmatch("[^,]+") do local ok,e=pcall(luac[m],proto); if not ok then print("MODERR",m,e);break end end
proto = luac.undump(luac.dump(proto), false) -- mirror real dump->load path
local function scan(p,d,name)
  local ms=p.maxstacksize
  for i=1,p.sizecode do
    local ins=p.code[i]; local op=ins%64
    if op==4 then
      local a=math.floor(ins/64)%256
      local b=math.floor(ins/8388608)%512
      local c=math.floor(ins/16384)%512
      if b<a or b>=ms then io.write(string.format("%s ms=%d ABNORMAL LOADNIL pc=%d A=%d B=%d\n",name,ms,i-1,a,b)) end
    end
  end
  if p.p then for i=1,p.sizep do scan(p.p[i],d+1,name.."/c"..i) end end
end
scan(proto,0,"main")
print("scan done")
