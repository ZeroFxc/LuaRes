local luac = require("luac")
-- minimal: for loop + string constant
local code = [[
local s = "hello world"
local sum = 0
for i = 1, #s do
    sum = sum + i
end
print(s, sum)
]]
local function test(mods, label)
    io.write(label.." ... ")
    io.flush()
    luac.srand(1)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for _, m in ipairs(mods) do luac[m.."_c"](p) end
    local d = luac.dump(p)
    local r, err = load(d)
    if not r then print("LOAD FAIL: "..tostring(err)); return end
    r()
    print("PASS")
end
local pre = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate"}
test(pre, "pre7")
test(pre, "pre7")
test(pre, "pre7")
test(pre, "pre7")
test(pre, "pre7")
local pre2 = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","opaque_predicate"}
test(pre2, "pre7+op")
test(pre2, "pre7+op")
test(pre2, "pre7+op")
local pre3 = {"const_hide","const_shuffle","str_encrypt","instruction_mutate","num_obfuscate","str_split","bool_obfuscate","opaque_predicate","luac_obfuscate"}
test(pre3, "pre7+op+obf")
test(pre3, "pre7+op+obf")
test(pre3, "pre7+op+obf")
print("DONE")
