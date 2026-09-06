local luac = require("luac")
local junk_jmp = require("junk_jmp")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))

for count = 5, 30, 5 do
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
    print(string.format("fib count=%d: load=%s exec=%s %s",
        count, tostring(ok), tostring(exec_ok),
        exec_ok and "" or ("err=" .. tostring(err_msg or f))))
    if not exec_ok then break end
end
