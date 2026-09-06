local luac = require("luac")
local opaque_junk = require("opaque_junk")

local func = load("print('hello')")
local bc = string.dec(string.dump(func))

for trial = 1, 10 do
    local p = luac.undump(bc, false)
    opaque_junk.inject(p, {count = 1, recursive = false})
    local out = luac.dump(p)
    local ok, f = pcall(load, out)
    local exec_ok = false
    local err = ""
    if ok then
        local old_print = print
        print = function() end
        exec_ok, err = pcall(f)
        print = old_print
    end
    print(string.format("trial %d: load=%s exec=%s %s",
        trial, tostring(ok), tostring(exec_ok),
        exec_ok and "" or ("err=" .. tostring(err or f))))
end
