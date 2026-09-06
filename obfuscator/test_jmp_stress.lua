local luac = require("luac")
local junk_jmp = require("junk_jmp")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))

local passed = 0
local failed = 0
for trial = 1, 20 do
    local p = luac.undump(bc, false)
    junk_jmp.inject(p, {count = 50})
    local out = luac.dump(p)
    local ok, f = pcall(load, out)
    local exec_ok = false
    local err_msg = ""
    if ok then
        local old_print = print
        print = function() end
        exec_ok, err_msg = pcall(f)
        print = old_print
    end
    if exec_ok then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("trial %d FAILED: %s", trial, tostring(err_msg or f)))
    end
end
print(string.format("\nResult: %d passed, %d failed", passed, failed))
