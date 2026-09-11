local out = {}
local function P(...) local t={...} local s='' for i=1,select('#',...) do if i>1 then s=s..'|' end s=s..tostring(t[i]) end out[#out+1]=s end

local rc0=0
local q0=0
repeat q0=q0+1; rc0=rc0+2 until q0>=3
P("rep", rc0)
local rc1=0
local q1=0
repeat q1=q1+1; rc1=rc1+2 until q1>=2
P("rep", rc1)
if 6 > 2 then P("if", 1) else P("if", 0) end
P("n", 3)
P("n", 1)
local lm5={a=1,b=1,c="xyz"}
P("lrec", lm5.a, lm5.b, lm5.c)
local nc10=0
for k=1,4 do for m=1,2 do nc10=nc10+m end end
P("nest", nc10)
P("bool", false)
local function ff12(a) local r=0 for z=1,a do r=r+z end return r end
P("fn", ff12(6))
print(table.concat(out, "#"))
