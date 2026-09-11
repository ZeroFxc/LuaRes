local out = {}
local function P(...) local t={...} local s='' for i=1,select('#',...) do if i>1 then s=s..'|' end s=s..tostring(t[i]) end out[#out+1]=s end

local wc0=0
local k0=1
while k0<=1 do wc0=wc0+k0; k0=k0+1 end
P("while", wc0)
P("bool", true)
local lm2={a=1,b=2,c="cd"}
P("lrec", lm2.a, lm2.b, lm2.c)
local rc3=0
local q3=0
repeat q3=q3+1; rc3=rc3+2 until q3>=1
P("rep", rc3)
local function fp4(x) local h={p=x,q=x+1} return h.p+h.q end
P("fpt", fp4(4))
local function fp5(x) local h={p=x,q=x+1} return h.p+h.q end
P("fpt", fp5(5))
local ac6=0
for k=1,6 do ac6=ac6+k end
P("for", ac6)
local ic7=0
for k=1,5 do if k%2==0 then ic7=ic7+1 else ic7=ic7-1 end end
P("ibr", ic7)
local ls8=0
for k=1,6 do local row={k,k*2,"cd"}; ls8=ls8+row[1]+row[2] end
P("lrow", ls8)
local wc9=0
local k9=1
while k9<=6 do wc9=wc9+k9; k9=k9+1 end
P("while", wc9)
local t10 = {{}}
for k=1,3 do t10[k] = k*3 end
P("tbl", t10[1], t10[3], #t10)
local lt11={1,2,1,4,5}
P("larr", lt11[1], lt11[3], #lt11)
print(table.concat(out, "#"))
