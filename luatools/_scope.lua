local luac = require("luac")
local code = [[
local function fact(n) if n<=1 then return 1 end return n*fact(n-1) end
local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end
local function table_tests() local t={a=1,b=2,c=3} local s=0 for k,v in pairs(t) do s=s+v end return s end
local function string_tests() local s="hello" local s2=s.." world" local fmt=string.format("x=%d",42) return #s2+#fmt end
local total = fact(5)+fib(7)+table_tests()+string_tests()
print("TOTAL="..total)
]]
local mods = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","opaque_predicate","luac_obfuscate"}
luac.srand(1)
do
  local p = luac.undump(string.dec(string.dump(load(code), true)), false)
  for _, m in ipairs(mods) do luac[m.."_c"](p) end
  local d = luac.dump(p)
  local f = io.open("_scope.luac", "wb")
  f:write(d); f:close()
end
-- p is out of scope here, eligible for GC
local f = io.open("_scope.luac", "rb")
local d = f:read("*a"); f:close()
local r, err = load(d)
if not r then print("LOAD FAIL: "..tostring(err)); os.exit(1) end
r()
print("PASS (p out of scope)")
