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
P("bool", false)
local function ff12(a) local r=0 for z=1,a do r=r+z end return r end
P("fn", ff12(6))
local la13={{"ab",1},{"ab",2}}
P("lmat", la13[1][1], la13[2][2])
print(table.concat(out, "#"))
