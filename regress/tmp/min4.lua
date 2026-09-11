local out = {}
local function P(...) local t={...} local s='' for i=1,select('#',...) do if i>1 then s=s..'|' end s=s..tostring(t[i]) end out[#out+1]=s end

local function ff0(a) local r=0 for z=1,a do r=r+z end return r end
P("fn", ff0(3))
local la1={{"ab",1},{"ab",2}}
P("lmat", la1[1][1], la1[2][2])
P("n", 4)
local function ff3(a) local r=0 for z=1,a do r=r+z end return r end
P("fn", ff3(5))
print(table.concat(out, "#"))
