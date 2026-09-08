local luac = require("luac")
local code = [[
local function fact(n) if n<=1 then return 1 end return n*fact(n-1) end
local function fib(n) if n<=2 then return 1 end return fib(n-1)+fib(n-2) end
local function string_tests() local s="hello" local s2=s.." world" local fmt=string.format("x=%d y=%s",42,"ok") return #s2+#fmt end
local function loop_tests() local s=0 for i=1,10 do s=s+i end local j=0 while j<5 do j=j+1 s=s+j end return s end
local total = fact(5)+fib(7)+string_tests()+loop_tests()
print("TOTAL="..total)
]]
local mods = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","table_obfuscate","opaque_predicate","const_poison","opaque_junk","junk_jmp","junk_loadk","junk_move","luac_obfuscate"}
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
for _, m in ipairs(mods) do luac[m.."_c"](p) end
print("code="..p.sizecode)
local asbx = 0
local bad = 0
for i=0,p.sizecode-1 do
    local inst = p.code[i]
    local op = inst % 64
    if op==30 or op==39 or op==40 or op==42 then
        asbx = asbx + 1
        local sbx = math.floor(inst / 16384) - 131071
        local target = i + sbx + 1
        if target < 0 or target >= p.sizecode then
            bad = bad + 1
            if bad <= 3 then print("BAD "..i.." op="..op.." sbx="..sbx.." tgt="..target) end
        end
    end
end
print("asbx="..asbx.." bad="..bad)
