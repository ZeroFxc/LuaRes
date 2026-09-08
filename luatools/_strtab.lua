local luac = require("luac")
local function test(extra_func, label)
    local code = [[
local function fact(n) if n<=1 then return 1 end return n*fact(n-1) end
local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end
local function math_tests() local x=3.14 local y=2.71 return math.floor(x*y)+math.ceil(x+y) end
]] .. extra_func .. [[
local total = fact(5)+fib(7)+math_tests()+extra()
print("TOTAL="..total)
]]
    local mods = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","opaque_predicate","luac_obfuscate"}
    io.write(label.." ... ")
    io.flush()
    luac.srand(1)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for _, m in ipairs(mods) do luac[m.."_c"](p) end
    local d = luac.dump(p)
    local r, err = load(d)
    if not r then print("LOAD FAIL"); return end
    r()
    print("PASS")
end
test([[local function extra() local s="hello" local s2=s.." world" local fmt=string.format("x=%d",42) return #s2+#fmt end]], "string_only")
test([[local function extra() local t={a=1,b=2} local s=0 for k,v in pairs(t) do s=s+v end return s end]], "table_only")
print("DONE")
