local protect = require("protect")
local luac = require("luac")

local func = loadfile("test_multi_func.lua")
local bc = string.dec(string.dump(func))

local protected, pstats = protect(bc)
print("Protected: " .. #protected .. " bytes")

-- 测试各个去混淆模块
local mods = {
    "deop48",
    "dejunk_jmp",
    "deopaque_junk",
    "dejunk_loadk",
    "dejunk_move",
}

for _, modname in ipairs(mods) do
    local p = luac.undump(protected, false)
    local m = require(modname)
    local removed = m.remove(p)
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
    print(string.format("%-15s: removed=%-4d size=%-6d load=%s exec=%s %s",
        modname, removed, #out, tostring(ok), tostring(exec_ok),
        exec_ok and "" or ("err=" .. tostring(err or f))))
end

-- 测试组合: deop48 + dejunk_jmp + deopaque_junk (安全的)
print("\n=== Safe combo: deop48 + dejunk_jmp + deopaque_junk ===")
local p = luac.undump(protected, false)
require("deop48").remove(p)
require("dejunk_jmp").remove(p)
require("deopaque_junk").remove(p)
local out = luac.dump(p)
local ok, f = pcall(load, out)
print("Size: " .. #protected .. " -> " .. #out)
print("Load: " .. tostring(ok))
if ok then
    local old = print
    local outputs = {}
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok, err = pcall(f)
    print = old
    print("Exec: " .. tostring(exec_ok))
    if not exec_ok then print("Error: " .. tostring(err)) end
    print("Last: " .. outputs[#outputs])
end
