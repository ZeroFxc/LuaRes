local luac = require("luac")
local code = [[
local function fact(n) if n<=1 then return 1 end return n*fact(n-1) end
local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end
local function string_tests() local s="hello" local s2=s.." world" local fmt=string.format("x=%d y=%s",42,"ok") return #s2+#fmt end
local function loop_tests() local s=0 for i=1,10 do s=s+i end local j=0 while j<5 do j=j+1 s=s+j end return s end
local total = fact(5)+fib(7)+string_tests()+loop_tests()
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
test({"str_encrypt"}, "str_enc+obf")
test({"str_encrypt","num_obfuscate"}, "str_enc+num+obf")
test({"str_encrypt","str_split"}, "str_enc+split+obf")
test({"const_hide","const_shuffle","str_encrypt"}, "ch+cs+se+obf")
test({"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","table_obfuscate"}, "first8+obf")
print("DONE")
