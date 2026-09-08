local luac = require("luac")
local mods = {"const_hide_c","const_shuffle_c","str_encrypt_c","instruction_mutate_c","num_obfuscate_c","str_split_c","bool_obfuscate_c","table_obfuscate_c","opaque_predicate_c","const_poison_c","opaque_junk_c","junk_jmp_c","junk_loadk_c","junk_move_c","luac_obfuscate_c","luac_flatten_c","debug_strip_c","antidec_c","proto_shuffle_c","live_range_split_c","op48_junk_c"}
local code = [[
print(6)
print("6")
print({6})
print({"6"})
print(true)
print(false)
print(nil)
print(6.6)
print((function (x) return {x} end)(6))
print((function (x) return x end)(6))
print((function() return 6 end)())
print((function (...) return ... end)(6))
print((function (...) return {...} end)(6))
print(#"6")
print(tostring(6).."")
local ver = _VERSION
if ver == "Lua 5.2" then
    print("运行在 Lua 5.2")
elseif ver == "Lua 5.3" then
    print("运行在 Lua 5.3")
elseif ver == "Lua 5.4" then
    print("运行在 Lua 5.4")
else
    print("未知版本:", ver)
end
]]
local function tos(v)
    if type(v) == "table" then return "table" end
    return tostring(v)
end
local function run(src)
    local old = print; local out = {}
    print = function(...)
        local args = {...}
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tos(args[i]) end
        out[#out+1] = table.concat(parts, "\t")
    end
    local ok, e = pcall(load(src))
    print = old
    if not ok then return nil, e end
    return out
end
local base_out, base_err = run(code)
if not base_out then print("BASELINE FAIL: "..base_err); return end
local pass, fail = 0, 0
for seed = 1, 5 do
    luac.srand(seed)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for _, m in ipairs(mods) do luac[m](p) end
    local src = luac.vm_embed_c(p)
    local out, err = run(src)
    if not out then
        print("seed "..seed.." EXEC FAIL: "..tostring(err))
        fail = fail + 1
    else
        local ok = true
        for i = 1, #base_out do
            if base_out[i] ~= out[i] then
                ok = false
                print("seed "..seed.." line "..i..": expected '"..base_out[i].."' got '"..tostring(out[i]).."'")
            end
        end
        if ok then pass = pass + 1 else fail = fail + 1 end
    end
end
print(string.format("ALL+VM: %d/%d PASS", pass, pass+fail))
