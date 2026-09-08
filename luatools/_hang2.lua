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
    local d = luac.dump(p)
    local r, err = load(d)
    if not r then print("LOAD FAIL"); return end
    local old = print; local cap = {}
    print = function(...) cap[#cap+1]=table.concat({...},"\t") end
    local co = coroutine.create(r)
    local ok, res = coroutine.resume(co)
    local start = os.clock()
    while coroutine.status(co) == "suspended" and os.clock() - start < 3 do
        ok, res = coroutine.resume(co)
    end
    if coroutine.status(co) == "suspended" then
        print("HANG (code="..p.sizecode..")"); coroutine.close(co)
    else
        print = old
        if not ok then print("ERR: "..tostring(res)) else print("PASS: "..table.concat(cap,"|")) end
    end
end

local all = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","table_obfuscate","opaque_predicate","const_poison","opaque_junk","junk_jmp","junk_loadk","junk_move","luac_obfuscate","luac_flatten","debug_strip","antidec","proto_shuffle","live_range_split","op48_junk"}

-- without luac_obfuscate
local no_obf = {}
for _, m in ipairs(all) do if m ~= "luac_obfuscate" then no_obf[#no_obf+1] = m end end
test(no_obf, "no_luac_obfuscate")

-- only flatten
test({"luac_flatten"}, "only_flatten")

-- luac_obfuscate + flatten
test({"luac_obfuscate","luac_flatten"}, "obf+flatten")

-- all
test(all, "all")

print("DONE")
