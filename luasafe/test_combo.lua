local protect = require("protect")
local luac = require("luac")

local func = loadfile("test_multi_func.lua")
local bc = string.dec(string.dump(func))
local protected = protect(bc)
print("Protected: " .. #protected .. " bytes")

local function test_combo(name, mod_list)
    local p = luac.undump(protected, false)
    for _, m in ipairs(mod_list) do
        require(m).remove(p)
    end
    local out = luac.dump(p)
    local ok, f = pcall(load, out)
    local exec_ok = false
    local err = ""
    if ok then
        local old = print
        print = function() end
        exec_ok, err = pcall(f)
        print = old
    end
    print(string.format("%-40s: size=%-6d load=%s exec=%s %s",
        name, #out, tostring(ok), tostring(exec_ok),
        exec_ok and "OK" or ("err=" .. tostring(err or f))))
end

test_combo("deop48", {"deop48"})
test_combo("deop48+dejunk_jmp", {"deop48", "dejunk_jmp"})
test_combo("deop48+dejunk_jmp+dejunk_loadk", {"deop48", "dejunk_jmp", "dejunk_loadk"})
test_combo("deop48+dejunk_jmp+dejunk_move", {"deop48", "dejunk_jmp", "dejunk_move"})
test_combo("deop48+dejunk_jmp+loadk+move", {"deop48", "dejunk_jmp", "dejunk_loadk", "dejunk_move"})
test_combo("all 5", {"deop48", "dejunk_jmp", "deopaque_junk", "dejunk_loadk", "dejunk_move"})

-- 测试顺序: dejunk_loadk 在 deop48 之前
test_combo("loadk FIRST then deop48+jmp", {"dejunk_loadk", "deop48", "dejunk_jmp"})
