local luac = require("luac")
local funcs = {
    "local function fact(n) if n<=1 then return 1 end return n*fact(n-1) end",
    "local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end",
    "local function table_tests() local t={a=1,b=2,c=3} local s=0 for k,v in pairs(t) do s=s+v end return s end",
    "local function string_tests() local s=\"hello\" local s2=s..\" world\" local len=#s2 local upper=string.upper(s) local sub=string.sub(s2,1,5) local fmt=string.format(\"x=%d y=%s\",42,\"ok\") return len+#upper+#sub+#fmt end",
}
local calls = {"fact(5)","fib(7)","table_tests()","string_tests()"}
local code = ""
for i=1,4 do code = code .. funcs[i] .. "\n" end
code = code .. "local total = " .. table.concat(calls, "+") .. "\nprint(\"TOTAL=\"..total)\n"
local mods = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","opaque_predicate","luac_obfuscate"}
for seed=1,10 do
    io.write("seed="..seed.." ... ")
    io.flush()
    luac.srand(seed)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for _, m in ipairs(mods) do luac[m.."_c"](p) end
    local d = luac.dump(p)
    local r, err = load(d)
    if not r then print("LOAD FAIL"); goto continue end
    r()
    print("PASS")
    ::continue::
end
print("DONE")
