local luac = require("luac")
local target = [[local s='hello' local s2=s..' world' local a=string.upper(s) local b=string.sub(s2,1,5) local c=string.format('x=%d y=%s',42,'ok') print(#s2+#a+#b+#c)]]

local function test(mods, seed)
    luac.srand(seed)
    local func = load(target)
    local bc = string.dec(string.dump(func, true))
    local p = luac.undump(bc, false)
    for _, m in ipairs(mods) do luac[m.."_c"](p) end
    local d = luac.dump(p)
    local r, err = load(d)
    if not r then return "LOAD FAIL: "..tostring(err) end
    local old = print; local cap = {}
    print = function(...) cap[#cap+1]=table.concat({...},"\t") end
    local ok, e = pcall(r)
    print = old
    if not ok then return "RUN ERR: "..tostring(e) end
    return "PASS: "..table.concat(cap,"|")
end

print("=== no flatten ===")
for seed = 1, 5 do
    print("seed="..seed.." "..test({"str_encrypt","num_obfuscate","opaque_predicate"}, seed))
end
print("=== with flatten ===")
for seed = 1, 5 do
    print("seed="..seed.." "..test({"str_encrypt","num_obfuscate","opaque_predicate","luac_flatten"}, seed))
end
print("=== only num_obf+flatten ===")
for seed = 1, 5 do
    print("seed="..seed.." "..test({"num_obfuscate","luac_flatten"}, seed))
end
print("=== only opaque+flatten ===")
for seed = 1, 5 do
    print("seed="..seed.." "..test({"opaque_predicate","luac_flatten"}, seed))
end
print("DONE")
