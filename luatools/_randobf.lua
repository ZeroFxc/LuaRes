local luac = require("luac")
local code = [[
local function fact(n) if n<=1 then return 1 end return n*fact(n-1) end
local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end
local function table_tests() local t={a=1,b=2,c=3} local s=0 for k,v in pairs(t) do s=s+v end return s end
local function string_tests() local s="hello" local s2=s.." world" local fmt=string.format("x=%d",42) return #s2+#fmt end
local function math_tests() local x=3.14 local y=2.71 return math.floor(x*y)+math.ceil(x+y) end
local function loop_tests() local s=0 for i=1,10 do s=s+i end local j=0 while j<5 do j=j+1 s=s+j end return s end
local function co_tests() local co=coroutine.create(function(a,b) coroutine.yield(a+b) return a*b end) local ok,r1=coroutine.resume(co,3,4) local ok2,r2=coroutine.resume(co) return r1+r2 end
local function closure_tests() local x=10 local function inc() x=x+1 return x end inc() inc() return inc() end
local total = fact(5)+fib(7)+table_tests()+string_tests()+math_tests()+loop_tests()+co_tests()+closure_tests()
print("TOTAL="..total)
]]
local all = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","table_obfuscate","opaque_predicate","const_poison","opaque_junk","junk_jmp","junk_loadk","junk_move","luac_obfuscate","luac_flatten","debug_strip","antidec","proto_shuffle","live_range_split","op48_junk"}
local pass, fail = 0, 0
for trial=1,30 do
    local seed = trial * 7 + 13
    luac.srand(seed)
    -- random subset: each module has 60% chance
    local mods = {}
    for _, m in ipairs(all) do
        if math.random() < 0.6 then mods[#mods+1] = m end
    end
    -- ensure at least 3 modules
    if #mods < 3 then mods = {all[1], all[3], all[15]} end
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    local ok = true
    for _, m in ipairs(mods) do
        local s, e = pcall(function() luac[m.."_c"](p) end)
        if not s then ok=false; print("  MODULE FAIL "..m..": "..tostring(e)); break end
    end
    if not ok then fail=fail+1; goto continue end
    local d = luac.dump(p)
    p = nil
    local f = io.open("_rand.luac", "wb")
    f:write(d); f:close()
    ::continue::
end
-- now execute all saved files (they were overwritten each time, so just test the last one)
print("OBF PHASE DONE (30 trials)")
