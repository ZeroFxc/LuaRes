local luac = require("luac")
local mods = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","table_obfuscate","opaque_predicate","const_poison","opaque_junk","junk_jmp","junk_loadk","junk_move","luac_obfuscate","luac_flatten","debug_strip","antidec","proto_shuffle","live_range_split","op48_junk"}

local funcs = {
    fact = [[local function fact(n) if n<=1 then return 1 end return n*fact(n-1) end]],
    fib = [[local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end]],
    tab = [[local function tab() local t={a=1,b=2,c=3} local s=0 for k,v in pairs(t) do s=s+v end return s end]],
    str = [[local function str() local s="hello" local s2=s.." world" return #s2+#string.upper(s)+#string.sub(s2,1,5) end]],
    math = [[local function mth() local x=3.14 local y=2.71 return math.floor(x*y)+math.ceil(x+y) end]],
    loop = [[local function lp() local s=0 for i=1,10 do s=s+i end return s end]],
    co = [[local function cof() local co=coroutine.create(function(a,b) coroutine.yield(a+b) return a*b end) local _,r1=coroutine.resume(co,3,4) local _,r2=coroutine.resume(co) return r1+r2 end]],
    cl = [[local function cl() local x=10 local function inc() x=x+1 return x end inc() inc() return inc() end]],
}
local calls = {fact="fact(5)", fib="fib(7)", tab="tab()", str="str()", math="mth()", loop="lp()", co="cof()", cl="cl()"}
local order = {"fact","fib","tab","str","math","loop","co","cl"}

for nfunc = 5, 8 do
    local code = ""
    local callparts = {}
    for i = 1, nfunc do
        local name = order[i]
        code = code .. funcs[name] .. "\n"
        callparts[#callparts+1] = calls[name]
    end
    code = code .. "print(" .. table.concat(callparts, "+") .. ")"
    io.write(nfunc.." funcs ... ")
    io.flush()
    luac.srand(1)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for _, m in ipairs(mods) do luac[m.."_c"](p) end
    local d = luac.dump(p)
    local r, err = load(d)
    if not r then print("LOAD FAIL"); goto next end
    local old = print; local cap = {}
    print = function(...) cap[#cap+1]=table.concat({...},"\t") end
    local ok, e = pcall(r)
    print = old
    if not ok then print("ERR/HANG: "..tostring(e)) else print("PASS: "..table.concat(cap,"|")) end
    ::next::
end
print("DONE")
