-- dump_embed.lua: apply modules then emit vm_embed source to arg4
local luac=require("luac")
local function rf(p) local f=assert(io.open(p,"rb"));local d=f:read("*a");f:close();return d end
local src=rf(arg[1])
if arg[3] then luac.srand(tonumber(arg[3]) or 0) end
local proto=luac.undump(string.dec(string.dump(assert(load(src)),true)),false)
for m in arg[2]:gmatch("[^,]+") do
  if m=="vm_reg_shuffle_c" then luac[m](proto,{seed=tonumber(arg[3]) or 0})
  elseif m=="vm_const_shuffle_c" then luac[m](proto,{seed=tonumber(arg[3]) or 0})
  elseif m=="vm_dispatch_shuffle_c" then luac[m](proto,{seed=tonumber(arg[3]) or 0,mode=0})
  else luac[m](proto) end
end
local out=luac.vm_embed_c(proto,{luajit_compat=true})
local f=assert(io.open(arg[4],"wb"));f:write(out);f:close()
io.write("EMBED_LEN "..#out.."\n")
