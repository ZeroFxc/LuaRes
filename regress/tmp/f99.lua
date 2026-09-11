local out = {}
local function P(...) local t={...} local s='' for i=1,select('#',...) do if i>1 then s=s..'|' end s=s..tostring(t[i]) end out[#out+1]=s end

local lt0={1,2,4,4,5}
P("larr", lt0[1], lt0[3], #lt0)
local function ff1(a) local r=0 for z=1,a do r=r+z end return r end
P("fn", ff1(2))
if 6 > 2 then P("if", 1) else P("if", 0) end
local la3={{"xyz",1},{"xyz",2}}
P("lmat", la3[1][1], la3[2][2])
local nc4=0
for k=1,4 do for m=1,2 do nc4=nc4+m end end
P("nest", nc4)
local ls5=0
for k=1,6 do local row={k,k*2,"cd"}; ls5=ls5+row[1]+row[2] end
P("lrow", ls5)
P("bool", false)
local ic7=0
for k=1,4 do if k%2==0 then ic7=ic7+1 else ic7=ic7-1 end end
P("ibr", ic7)
P("n", 4)
P("bool", false)
P("s", "cd")
local wc11=0
local k11=1
while k11<=6 do wc11=wc11+k11; k11=k11+1 end
P("while", wc11)
print(table.concat(out, "#"))
