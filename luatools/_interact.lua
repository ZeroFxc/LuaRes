local luac = require("luac")
local code = [[
local function fact(n) if n<=1 then return 1 end return n*fact(n-1) end
local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end
local function table_tests() local t={a=1,b=2,c=3} local s=0 for k,v in pairs(t) do s=s+v end return s end
local function string_tests() local s="hello" local s2=s.." world" local len=#s2 local upper=string.upper(s) local sub=string.sub(s2,1,5) local fmt=string.format("x=%d y=%s",42,"ok") return len+#upper+#sub+#fmt end
local function math_tests() local x=3.14 local y=2.71 return math.floor(x*y)+math.ceil(x+y) end
local function loop_tests() local s=0 for i=1,10 do s=s+i end local j=0 while j<5 do j=j+1 s=s+j end return s end
local function co_tests() local co=coroutine.create(function(a,b) coroutine.yield(a+b) return a*b end) local ok,r1=coroutine.resume(co,3,4) local ok2,r2=coroutine.resume(co) return r1+r2 end
local function closure_tests() local x=10 local function inc() x=x+1 return x end inc() inc() return inc() end
local total = fact(5)+fib(7)+table_tests()+string_tests()+math_tests()+loop_tests()+co_tests()+closure_tests()
print("TOTAL="..total)
]]
local function test(mods, label)
    io.write(label.." ... ")
    io.flush()
    luac.srand(1)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for _, m in ipairs(mods) do luac[m.."_c"](p) end
    luac.luac_obfuscate_c(p)
    local d = luac.dump(p)
    local r, err = load(d)
    if not r then print("LOAD FAIL"); return end
    r()
    print("PASS")
end
test({"junk_jmp"}, "junk_jmp+obf")
test({"opaque_predicate"}, "opaque_pred+obf")
test({"opaque_junk"}, "opaque_junk+obf")
test({"junk_jmp","opaque_junk"}, "jj+oj+obf")
test({"junk_jmp","opaque_predicate"}, "jj+op+obf")
test({"opaque_predicate","opaque_junk"}, "op+oj+obf")
test({"junk_jmp","opaque_predicate","opaque_junk"}, "jj+op+oj+obf")
test({"junk_move"}, "junk_move+obf")
test({"junk_loadk"}, "junk_loadk+obf")
test({"junk_jmp","junk_loadk","junk_move"}, "jj+jl+jm+obf")
print("DONE")
