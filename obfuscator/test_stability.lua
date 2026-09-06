-- test_deprotect_stability.lua
local p = require("protect")
local d = require("deprotect")
local luac = require("luac")

local func = loadfile("test_multi_func.lua")
local bc = string.dec(string.dump(func))

local pass_count = 0
local fail_count = 0

for seed = 1, 20 do
    -- 清除所有相关模块的缓存（保留 luac C 模块）
    for k, _ in pairs(package.loaded) do
        if k ~= "luac" and (k:match("junk") or k:match("deop") or k:match("dejunk") or k:match("deopaque")
           or k:match("fix_anti") or k:match("deprotect") or k:match("protect")
           or k:match("deflatten") or k:match("deconst") or k:match("dedebug")
           or k:match("deinstruction") or k:match("de_junk")
           or k:match("debug_strip") or k:match("const_shuffle") or k:match("instruction_mutate")
           or k:match("luac_flatten") or k:match("luac_obfuscate")
           or k:match("opaque_predicate") or k:match("opaque_junk")
           or k:match("antidec") or k:match("op48_junk")) then
            package.loaded[k] = nil
        end
    end
    local p = require("protect")
    local d = require("deprotect")
    local prot = p(bc, {seed = seed * 1000 + 7})
    local clean, stats = d.clean(prot, {})
    local ok, f = pcall(load, clean)
    if ok then
        local old_print = print
        local out = {}
        print = function(...) table.insert(out, table.concat({...}, "\t")) end
        local e, err = pcall(f)
        print = old_print
        if e then
            pass_count = pass_count + 1
            print(string.format("seed %d: PASS (code=%d)", seed, stats and stats.cleaned_size or 0))
        else
            fail_count = fail_count + 1
            print(string.format("seed %d: FAIL exec: %s", seed, tostring(err)))
        end
    else
        fail_count = fail_count + 1
        print(string.format("seed %d: FAIL load", seed))
    end
end

print(string.format("\nResult: %d pass, %d fail", pass_count, fail_count))
