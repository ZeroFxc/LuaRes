local luac = require("luac")
local mods = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","table_obfuscate","opaque_predicate","const_poison","opaque_junk","junk_jmp","junk_loadk","junk_move","luac_obfuscate","luac_flatten","debug_strip","antidec","proto_shuffle","live_range_split","op48_junk"}

local code = [[
local function fact(n) if n<=1 then return 1 end return n*fact(n-1) end
local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end
local function table_tests() local t={a=1,b=2,c=3} local s=0 for k,v in pairs(t) do s=s+v end return s end
local function string_tests() local s="hello" local s2=s.." world" local len=#s2 local upper=string.upper(s) local sub=string.sub(s2,1,5) local fmt=string.format("x=%d y=%s",42,"ok") return len+#upper+#sub+#fmt end
local function math_tests() local x=3.14 local y=2.71 return math.floor(x*y)+math.ceil(x+y) end
local function loop_tests() local s=0 for i=1,10 do s=s+i end local j=0 while j<5 do j=j+1 s=s+j end return s end
local function co_tests() local co=coroutine.create(function(a,b) coroutine.yield(a+b) return a*b end) local ok,r1=coroutine.resume(co,3,4) local ok2,r2=coroutine.resume(co) return r1+r2 end
local function closure_tests() local x=10 local function inc() x=x+1 return x end inc() inc() return inc() end
io.stderr:write("calling fact\n")
local r1 = fact(5)
io.stderr:write("fact done\n")
local r2 = fib(7)
io.stderr:write("fib done\n")
local r3 = table_tests()
io.stderr:write("table done\n")
local r4 = string_tests()
io.stderr:write("string done\n")
local r5 = math_tests()
io.stderr:write("math done\n")
local r6 = loop_tests()
io.stderr:write("loop done\n")
local r7 = co_tests()
io.stderr:write("co done\n")
local r8 = closure_tests()
io.stderr:write("closure done\n")
print("TOTAL="..(r1+r2+r3+r4+r5+r6+r7+r8))
]]

luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
for _, m in ipairs(mods) do luac[m.."_c"](p) end
local d = luac.dump(p)
local r, err = load(d)
if not r then print("LOAD FAIL: "..tostring(err)); os.exit(1) end
print("running...")
r()
print("DONE")
