-- test_seed_4007.lua
local p = require("protect")
local d = require("deprotect")
local func = loadfile("test_multi_func.lua")
local bc = string.dec(string.dump(func))

for i = 1, 5 do
    local prot = p(bc, {seed = 4007})
    local clean, stats = d.clean(prot, {})
    local ok, f = pcall(load, clean)
    if ok then
        local old_print = print
        local out = {}
        print = function(...) table.insert(out, table.concat({...}, "\t")) end
        local e, err = pcall(f)
        print = old_print
        if e then
            print(string.format("Run %d: PASS (code=%d)", i, #clean))
        else
            print(string.format("Run %d: FAIL exec: %s", i, tostring(err)))
        end
    else
        print(string.format("Run %d: FAIL load", i))
    end
end
