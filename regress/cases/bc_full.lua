local out = {}
local function P(...) local t={...} local s='' for i=1,select('#',...) do if i>1 then s=s..'|' end s=s..tostring(t[i]) end out[#out+1]=s end

if 3 > 2 then P("if", 1) else P("if", 0) end
local ac1=0
for k=1,2 do ac1=ac1+k end
P("for", ac1)
P("bool", false)
P("n", 4)
if 2 > 2 then P("if", 1) else P("if", 0) end
local ls5=0
for k=1,6 do local row={k,k*2,"xyz"}; ls5=ls5+row[1]+row[2] end
P("lrow", ls5)
if 3 > 2 then P("if", 1) else P("if", 0) end
local lm7={a=1,b=6,c="ef"}
P("lrec", lm7.a, lm7.b, lm7.c)
local ic8=0
for k=1,6 do if k%2==0 then ic8=ic8+1 else ic8=ic8-1 end end
P("ibr", ic8)
if 6 > 2 then P("if", 1) else P("if", 0) end
local ls10=0
for k=1,6 do local row={k,k*2,"xyz"}; ls10=ls10+row[1]+row[2] end
P("lrow", ls10)
local sc11=""
for k=1,2 do sc11=sc11.."a" end
P("cat", sc11)
if 3 > 2 then P("if", 1) else P("if", 0) end
if 4 > 2 then P("if", 1) else P("if", 0) end
local function ff14(a) local r=0 for z=1,a do r=r+z end return r end
P("fn", ff14(5))
local nc15=0
for k=1,2 do for m=1,2 do nc15=nc15+m end end
P("nest", nc15)
local ls16=0
for k=1,4 do local row={k,k*2,"ab"}; ls16=ls16+row[1]+row[2] end
P("lrow", ls16)
P("s", "cd")
print(table.concat(out, "#"))
