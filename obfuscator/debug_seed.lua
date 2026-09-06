-- debug_seed.lua
local p = require("protect")
local luac = require("luac")

local func = loadfile("test_multi_func.lua")
local bc = string.dec(string.dump(func))
local prot = p(bc, {seed = 4007})
print("prot size: " .. #prot)

local passes = {
    {"deop48", require("deop48").remove},
    {"de_junk_obfuscate", require("de_junk_obfuscate").remove},
    {"deopaque_predicate", require("deopaque_predicate").remove},
    {"deopaque_junk", require("deopaque_junk").remove},
    {"dejunk_jmp", require("dejunk_jmp").remove},
    {"dejunk_loadk", require("dejunk_loadk").remove},
    {"dejunk_move", require("dejunk_move").remove},
    {"deinstruction_mutate", require("deinstruction_mutate").remove},
    {"deconst_shuffle", require("deconst_shuffle").sort},
    {"dedebug_strip", require("dedebug_strip").restore},
    {"deflatten", require("deflatten").partial_restore},
}

local function test_with_n_passes(n)
    local proto = luac.undump(prot, false)
    for i = 1, n do
        passes[i][2](proto)
    end
    require("fix_antidec").fix(proto)
    local out = luac.dump(proto)
    local ok, f = pcall(load, out)
    if not ok then
        return "LOAD_FAIL"
    end
    local old_print = print
    local out2 = {}
    print = function(...) table.insert(out2, table.concat({...}, "\t")) end
    local e, err = pcall(f)
    print = old_print
    if e then
        return "PASS"
    else
        return "FAIL: " .. tostring(err)
    end
end

for i = 0, #passes do
    local result = test_with_n_passes(i)
    print(string.format("After %d passes (%s): %s", i, i > 0 and passes[i][1] or "none", result))
end
