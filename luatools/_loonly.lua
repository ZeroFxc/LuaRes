local luac = require("luac")
local code = [[
local function fact(n) if n<=1 then return 1 end return n*fact(n-1) end
local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end
local function string_tests() local s="hello" local s2=s.." world" local fmt=string.format("x=%d y=%s",42,"ok") return #s2+#fmt end
local function loop_tests() local s=0 for i=1,10 do s=s+i end local j=0 while j<5 do j=j+1 s=s+j end return s end
local total = fact(5)+fib(7)+string_tests()+loop_tests()
print("TOTAL="..total)
]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.luac_obfuscate_c(p)
local d = luac.dump(p)
local r, err = load(d)
if not r then print("LOAD FAIL: "..tostring(err)); os.exit(1) end
r()
print("PASS")
