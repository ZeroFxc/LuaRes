local luac = require("luac")
local code = [[
local function fact(n) if n<=1 then return 1 end return n*fact(n-1) end
local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end
local function math_tests() local x=3.14 local y=2.71 return math.floor(x*y)+math.ceil(x+y) end
local function string_tests() local s="hello" local s2=s.." world" local fmt=string.format("x=%d",42) return #s2+#fmt end
local total = fact(5)+fib(7)+math_tests()+string_tests()
print("TOTAL="..total)
]]
local function test(mods, label)
    io.write(label.." ... ")
    io.flush()
    luac.srand(1)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for _, m in ipairs(mods) do luac[m.."_c"](p) end
    local d = luac.dump(p)
    local r, err = load(d)
    if not r then print("LOAD FAIL: "..tostring(err)); return end
    r()
    print("PASS")
end
test({"const_hide","luac_obfuscate"}, "ch+obf")
test({"const_hide","str_encrypt","luac_obfuscate"}, "ch+se+obf")
test({"const_hide","str_encrypt","opaque_predicate","luac_obfuscate"}, "ch+se+op+obf")
test({"const_hide","const_shuffle","str_encrypt","num_obfuscate","opaque_predicate","luac_obfuscate"}, "ch+cs+se+num+op+obf")
print("DONE")
