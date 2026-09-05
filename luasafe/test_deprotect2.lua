local protect = require("protect")
local deprotect = require("deprotect")
local luac = require("luac")

local func = loadfile("test_multi_func.lua")
local bc = string.dec(string.dump(func))
local prot = protect(bc)
print("Protected: " .. #prot .. " bytes")

-- 测试各种选项组合
local options_list = {
    {name="all", opts={}},
    {name="no_opaque", opts={no_deopaque_junk=true}},
    {name="no_fix", opts={no_fix_anti_td=true}},
    {name="no_opaque_no_fix", opts={no_deopaque_junk=true, no_fix_anti_td=true}},
    {name="only_deop48", opts={no_dejunk_jmp=true, no_deopaque_junk=true, no_dejunk_loadk=true, no_dejunk_move=true, no_fix_anti_td=true}},
}

for _, item in ipairs(options_list) do
    local clean, stats = deprotect.clean(prot, item.opts)
    local ok, f = pcall(load, clean)
    local exec_ok = false
    local err = ""
    if ok then
        local old = print
        print = function() end
        exec_ok, err = pcall(f)
        print = old
    end
    print(string.format("%-20s: size=%-6d load=%s exec=%s %s",
        item.name, #clean, tostring(ok), tostring(exec_ok),
        exec_ok and "OK" or ("err=" .. tostring(err or f))))
end
