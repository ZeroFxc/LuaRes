local out = {}
local function P(...) local t={...} local s='' for i=1,select('#',...) do if i>1 then s=s..'|' end s=s..tostring(t[i]) end out[#out+1]=s end

local sc0=""
for k=1,6 do sc0=sc0.."a" end
P("cat", sc0)
if 3 > 2 then P("if", 1) else P("if", 0) end
local ic2=0
for k=1,1 do if k%2==0 then ic2=ic2+1 else ic2=ic2-1 end end
P("ibr", ic2)
if 4 > 2 then P("if", 1) else P("if", 0) end
local nc4=0
for k=1,3 do for m=1,2 do nc4=nc4+m end end
P("nest", nc4)
local ac5=0
for k=1,4 do ac5=ac5+k end
P("for", ac5)
local ac6=0
for k=1,5 do ac6=ac6+k end
P("for", ac6)
local wc7=0
local k7=1
while k7<=6 do wc7=wc7+k7; k7=k7+1 end
P("while", wc7)
local ic8=0
for k=1,1 do if k%2==0 then ic8=ic8+1 else ic8=ic8-1 end end
P("ibr", ic8)
P("bool", true)
local sc10=""
for k=1,2 do sc10=sc10.."a" end
P("cat", sc10)
if 6 > 2 then P("if", 1) else P("if", 0) end
local ac12=0
for k=1,4 do ac12=ac12+k end
P("for", ac12)
local function fp13(x) local h={p=x,q=x+1} return h.p+h.q end
P("fpt", fp13(2))
P("n", 3)
local function fp15(x) local h={p=x,q=x+1} return h.p+h.q end
P("fpt", fp15(4))
local t16 = {{}}
for k=1,3 do t16[k] = k*3 end
P("tbl", t16[1], t16[3], #t16)
local ls17=0
for k=1,3 do local row={k,k*2,"ab"}; ls17=ls17+row[1]+row[2] end
P("lrow", ls17)
print(table.concat(out, "#"))
