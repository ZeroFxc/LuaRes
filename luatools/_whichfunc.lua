local luac = require("luac")
local code = [[
local function fact(n) io.stderr:write("fact\n"); io.stderr:flush(); if n<=1 then return 1 end return n*fact(n-1) end
local function fib(n) io.stderr:write("fib\n"); io.stderr:flush(); if n<=2 then return 1 end return fib(n-1)+fib(n-2) end
local function math_tests() io.stderr:write("math\n"); io.stderr:flush(); local x=3.14 local y=2.71 return math.floor(x*y)+math.ceil(x+y) end
local function string_tests() io.stderr:write("string\n"); io.stderr:flush(); local s="hello" local s2=s.." world" local fmt=string.format("x=%d",42) return #s2+#fmt end
io.stderr:write("main start\n"); io.stderr:flush()
local total = fact(5)+fib(7)+math_tests()+string_tests()
io.stderr:write("main done\n"); io.stderr:flush()
print("TOTAL="..total)
]]
local mods = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","opaque_predicate","luac_obfuscate"}
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
for _, m in ipairs(mods) do luac[m.."_c"](p) end
local d = luac.dump(p)
local r, err = load(d)
if not r then print("LOAD FAIL: "..tostring(err)); os.exit(1) end
r()
print("PASS")
