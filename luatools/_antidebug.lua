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
local pre = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","table_obfuscate","opaque_predicate","const_poison","opaque_junk","junk_jmp","junk_loadk","junk_move","luac_obfuscate","luac_flatten","debug_strip"}

local function test(antidec_opts, label)
    io.write(label.." ... ")
    io.flush()
    luac.srand(1)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for _, m in ipairs(pre) do luac[m.."_c"](p) end
    if antidec_opts then
        luac.antidec_c(p, antidec_opts)
    else
        luac.antidec_c(p)
    end
    luac.proto_shuffle_c(p)
    luac.live_range_split_c(p)
    luac.op48_junk_c(p)
    print("main_stack="..p.maxstacksize)
    local d = luac.dump(p)
    local r, err = load(d)
    if not r then print("LOAD FAIL"); return end
    local old = print; local cap = {}
    print = function(...) cap[#cap+1]=table.concat({...},"\t") end
    local ok, e = pcall(r)
    print = old
    if not ok then print("ERR: "..tostring(e)) else print("PASS: "..table.concat(cap,"|")) end
end

test(nil, "full_antidec")
test({poison_header=false}, "no_header")
test({junk_upvalues=false}, "no_upvals")
test({junk_source=false}, "no_source")
test({strip_lineinfo=false}, "no_strip")
test({poison_header=false,junk_upvalues=false}, "no_header_no_upvals")
print("DONE")
