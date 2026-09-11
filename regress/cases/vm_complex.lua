local out = {}
local function va(...) return select("#", ...), ... end
do local n,a,b,c = va(1,2,3); out[#out+1] = table.concat({n,a,b,c}, ",") end
local function counter() local x=0; return function() x=x+1; return x end, function() return x end end
do local inc,get = counter(); inc(); inc(); out[#out+1] = get() end
local function sum(n,acc) acc=acc or 0; if n==0 then return acc end; return sum(n-1,acc+n) end
out[#out+1] = sum(10)
local f
do local y=10; f=function() return y end end
out[#out+1] = f()
local g
for i=1,3 do
  local z=i*2
  if i==2 then g=function() return z end; goto done end
end
::done::
out[#out+1] = g()
local function wrap(...) local args={...}; return function() return args[1]+args[2] end end
out[#out+1] = wrap(40,2)()
local function multi(...) return (function(...) return ... end)(...) end
out[#out+1] = table.concat({multi(7,8,9)}, ",")
print(table.concat(out, "#"))
