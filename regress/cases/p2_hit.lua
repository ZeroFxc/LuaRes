local out = {}
local function P(...) local t={...} local s='' for i=1,select('#',...) do if i>1 then s=s..'|' end s=s..tostring(t[i]) end out[#out+1]=s end

P("bool", false)
local function ff1(a) local r=0 for z=1,a do r=r+z end return r end
P("fn", ff1(4))
local t2 = {{}}
for k=1,3 do t2[k] = k*3 end
P("tbl", t2[1], t2[3], #t2)
local function fp3(x) local h={p=x,q=x+1} return h.p+h.q end
P("fpt", fp3(6))
P("n", 5)
local la5={{"cd",1},{"cd",2}}
P("lmat", la5[1][1], la5[2][2])
local rc6=0
local q6=0
repeat q6=q6+1; rc6=rc6+2 until q6>=4
P("rep", rc6)
local t7 = {{}}
for k=1,1 do t7[k] = k*1 end
P("tbl", t7[1], t7[1], #t7)
print(table.concat(out, "#"))
