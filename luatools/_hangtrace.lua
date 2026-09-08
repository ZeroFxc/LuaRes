local luac = require("luac")
local code = [[
local function fact(n) if n<=1 then return 1 end return n*fact(n-1) end
local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end
local function string_tests() local s="hello" local s2=s.." world" return #s2+#string.upper(s)+#string.sub(s2,1,5) end
local function loop_tests() local s=0 for i=1,10 do s=s+i end return s end
local function co_tests() local co=coroutine.create(function(a,b) coroutine.yield(a+b) return a*b end) local _,r1=coroutine.resume(co,3,4) local _,r2=coroutine.resume(co) return r1+r2 end
local total = fact(5)+fib(7)+string_tests()+loop_tests()+co_tests()
print("TOTAL="..total)
]]
local mods = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","table_obfuscate","opaque_predicate","const_poison","opaque_junk","junk_jmp","junk_loadk","junk_move","luac_obfuscate","luac_flatten","debug_strip","antidec","proto_shuffle","live_range_split","op48_junk"}

luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
print("initial: code="..p.sizecode.." k="..p.sizek.." stack="..p.maxstacksize)
for _, m in ipairs(mods) do
    io.write("  "..m.." ... ")
    io.flush()
    luac[m.."_c"](p)
    print("code="..p.sizecode.." k="..p.sizek.." stack="..p.maxstacksize)
end
print("all modules done, dumping...")
local d = luac.dump(p)
print("dump done, size="..#d..", loading...")
local r, err = load(d)
if not r then print("LOAD FAIL: "..tostring(err)); os.exit(1) end
print("load done, running...")
local old = print; local cap = {}
print = function(...) cap[#cap+1]=table.concat({...},"\t") end
local ok, e = pcall(r)
print = old
if not ok then print("RUN ERR: "..tostring(e))
else print("PASS: "..table.concat(cap,"|")) end
print("DONE")
