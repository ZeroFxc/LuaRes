local luac = require("luac")
local code = [[
print("hello world test string")
print("another string")
local t = {key1 = "value1", key2 = "value2"}
print(t.key1)
]]
local function run(src)
    local old = print; local out = {}
    print = function(...)
        local args = {...}; local parts = {}
        for i = 1, select("#", ...) do parts[i] = type(args[i])=="table" and "table" or tostring(args[i]) end
        out[#out+1] = table.concat(parts, "\t")
    end
    local ok, e = pcall(load(src))
    print = old
    if not ok then return nil, e end
    return out
end
local base = run(code)
print("baseline: "..table.concat(base, "|"))
-- test str_encrypt only
for seed = 1, 3 do
    luac.srand(seed)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    luac.str_encrypt_c(p)
    local src = luac.vm_embed_c(p)
    local out, err = run(src)
    if not out then print("se+vm seed"..seed.." FAIL: "..tostring(err))
    else print("se+vm seed"..seed..": "..table.concat(out, "|")) end
end
-- test const_hide only
for seed = 1, 3 do
    luac.srand(seed)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    luac.const_hide_c(p)
    local src = luac.vm_embed_c(p)
    local out, err = run(src)
    if not out then print("ch+vm seed"..seed.." FAIL: "..tostring(err))
    else print("ch+vm seed"..seed..": "..table.concat(out, "|")) end
end
print("DONE")
