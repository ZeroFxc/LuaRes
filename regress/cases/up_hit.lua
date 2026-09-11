local out = {}
local function P(...) local t={...} local s='' for i=1,select('#',...) do if i>1 then s=s..'|' end s=s..tostring(t[i]) end out[#out+1]=s end

local ac0=0
for k=1,2 do ac0=ac0+k end
P("for", ac0)
local wc1=0
local k1=1
while k1<=6 do wc1=wc1+k1; k1=k1+1 end
P("while", wc1)
P("bool", true)
local ic3=0
for k=1,5 do if k%2==0 then ic3=ic3+1 else ic3=ic3-1 end end
P("ibr", ic3)
P("s", "ab")
local sc5=""
for k=1,4 do sc5=sc5.."a" end
P("cat", sc5)
local t6 = {{}}
for k=1,5 do t6[k] = k*5 end
P("tbl", t6[1], t6[5], #t6)
local ic7=0
for k=1,3 do if k%2==0 then ic7=ic7+1 else ic7=ic7-1 end end
P("ibr", ic7)
local sc8=""
for k=1,6 do sc8=sc8.."a" end
P("cat", sc8)
if 6 > 2 then P("if", 1) else P("if", 0) end
P("s", "ab")
if 5 > 2 then P("if", 1) else P("if", 0) end
local lt12={1,2,6,4,5}
P("larr", lt12[1], lt12[3], #lt12)
local nc13=0
for k=1,4 do for m=1,2 do nc13=nc13+m end end
P("nest", nc13)
local function fp14(x) local h={p=x,q=x+1} return h.p+h.q end
P("fpt", fp14(4))
P("bool", true)
print(table.concat(out, "#"))
