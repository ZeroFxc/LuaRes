local out = {}
local function P(...) local t={...} local s='' for i=1,select('#',...) do if i>1 then s=s..'|' end s=s..tostring(t[i]) end out[#out+1]=s end

P("bool", true)
local function fp1(x) local h={p=x,q=x+1} return h.p+h.q end
P("fpt", fp1(2))
P("bool", true)
local ac3=0
for k=1,5 do ac3=ac3+k end
P("for", ac3)
P("bool", false)
local ac5=0
for k=1,4 do ac5=ac5+k end
P("for", ac5)
local ls6=0
for k=1,6 do local row={k,k*2,"ab"}; ls6=ls6+row[1]+row[2] end
P("lrow", ls6)
local function ff7(a) local r=0 for z=1,a do r=r+z end return r end
P("fn", ff7(3))
local ac8=0
for k=1,1 do ac8=ac8+k end
P("for", ac8)
local ic9=0
for k=1,4 do if k%2==0 then ic9=ic9+1 else ic9=ic9-1 end end
P("ibr", ic9)
local lt10={1,2,3,4,5}
P("larr", lt10[1], lt10[3], #lt10)
local t11 = {{}}
for k=1,5 do t11[k] = k*5 end
P("tbl", t11[1], t11[5], #t11)
print(table.concat(out, "#"))
