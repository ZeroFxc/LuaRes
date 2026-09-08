local luac = require("luac")

local function safe_tostring(v)
    if type(v) == 'table' then
        local parts = {}
        for k, vv in pairs(v) do parts[#parts+1] = tostring(k)..'='..tostring(vv) end
        return '{'..table.concat(parts,',')..'}'
    end
    return tostring(v)
end

local targets = {
    simple = "print(6) print('6') print({6}) print({'6'}) print(true) print(false) print(nil) print(6.6)",
    funcs = "local function f(x) return {x} end print(f(6)) local function g(x) return x end print(g(6))",
    vararg = "print((function(...) return ... end)(6)) print((function(...) return {...} end)(6))",
    ops = "print(#('6')) print(tostring(6)..'')",
    loops = [[local s=0 for i=1,20 do s=s+i end local j=0 while j<10 do j=j+1 s=s+j end repeat s=s+1 until s>100 print(s)]],
    strings = [[local s='hello' local s2=s..' world' local a=string.upper(s) local b=string.sub(s2,1,5) local c=string.format('x=%d y=%s',42,'ok') print(#s2+#a+#b+#c)]],
    tables = [[local t={a=1,b=2,c={d=3,e=4}} local s=0 for k,v in pairs(t) do if type(v)=='table' then for k2,v2 in pairs(v) do s=s+v2 end else s=s+v end end print(s)]],
    coroutine = [[local co=coroutine.create(function(a,b) coroutine.yield(a+b) return a*b end) local _,r1=coroutine.resume(co,3,4) local _,r2=coroutine.resume(co) print(r1+r2)]],
    closure = [[local x=10 local function inc() x=x+1 return x end inc() inc() print(inc())]],
    recursion = [[local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end print(fib(10))]],
    metatable = [[local t=setmetatable({},{__index=function(t,k) return #k end}) print(t.hello+t.world)]],
    numbers = [[local a=0xDEADBEEF local b=-42 local c=3.14159 print(a+b+c)]],
    concat = [[local s='' for i=1,50 do s=s..tostring(i) end print(#s)]],
}

local all_modules = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","table_obfuscate","opaque_predicate","const_poison","opaque_junk","junk_jmp","junk_loadk","junk_move","luac_obfuscate","luac_flatten","debug_strip","antidec","proto_shuffle","live_range_split","op48_junk"}

local function run_test(mods, target_code, seed)
    luac.srand(seed)
    local func = load(target_code)
    local bc = string.dec(string.dump(func, true))
    local p = luac.undump(bc, false)
    for _, m in ipairs(mods) do
        if luac[m.."_c"] then
            local ok, err = pcall(luac[m.."_c"], p)
            if not ok then return false, "MODULE "..m.." ERR: "..tostring(err) end
        end
    end
    local d = luac.dump(p)
    local r, err = load(d)
    if not r then return false, "LOAD FAIL: "..tostring(err) end
    local old = print; local cap = {}
    print = function(...)
        local t = {...}
        local parts = {}
        for i = 1, select('#', ...) do parts[i] = safe_tostring(t[i]) end
        cap[#cap+1] = table.concat(parts, "\t")
    end
    local ok, runerr = pcall(r)
    print = old
    if not ok then return false, "RUN ERR: "..tostring(runerr) end
    return true, table.concat(cap, "|")
end

-- baseline (no modules) to get expected output
local function baseline(target_code)
    local old = print; local cap = {}
    print = function(...)
        local t = {...}
        local parts = {}
        for i = 1, select('#', ...) do parts[i] = safe_tostring(t[i]) end
        cap[#cap+1] = table.concat(parts, "\t")
    end
    local f = load(target_code)
    pcall(f)
    print = old
    return table.concat(cap, "|")
end

local baselines = {}
for k, v in pairs(targets) do baselines[k] = baseline(v) end

math.randomseed(os.time())
local total = 0
local failed = 0
local failures = {}

for iter = 1, 100 do
    local n = math.random(3, 15)
    local shuffled = {}
    for i, m in ipairs(all_modules) do shuffled[i] = m end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    local mods = {}
    for i = 1, n do mods[i] = shuffled[i] end
    local order_map = {}
    for i, m in ipairs(all_modules) do order_map[m] = i end
    table.sort(mods, function(a,b) return order_map[a] < order_map[b] end)
    local tnames = {}
    for k in pairs(targets) do tnames[#tnames+1] = k end
    local tname = tnames[math.random(#tnames)]
    local seed = math.random(1, 200)
    total = total + 1
    local ok, msg = run_test(mods, targets[tname], seed)
    if not ok then
        failed = failed + 1
        failures[#failures+1] = string.format("iter=%d target=%s seed=%d mods=%s | %s", iter, tname, seed, table.concat(mods,","), msg)
    elseif msg ~= baselines[tname] then
        failed = failed + 1
        failures[#failures+1] = string.format("iter=%d target=%s seed=%d mods=%s | OUTPUT MISMATCH: got=%s expected=%s", iter, tname, seed, table.concat(mods,","), msg, baselines[tname])
    end
end

print(string.format("RESULT: %d/%d passed, %d failed", total-failed, total, failed))
for i, f in ipairs(failures) do print("  FAIL: "..f) end
print("DONE")
