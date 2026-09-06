local luac = require("luac")
local junk_jmp = require("junk_jmp")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))

-- 测试 count=1 到 5
for count = 1, 5 do
    local all_ok = true
    for trial = 1, 3 do
        local p = luac.undump(bc, false)
        junk_jmp.inject(p.p[3], {count = count, recursive = false})
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
        if not exec_ok then
            all_ok = false
            print(string.format("count=%d trial=%d: err=%s", count, trial, tostring(err_msg or f)))
            break
        end
    end
    if all_ok then
        print(string.format("count=%d: all OK", count))
    end
end
