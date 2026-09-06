local protect = require("protect")
local deprotect = require("deprotect")

-- 编译测试脚本
local func = loadfile("test_multi_func.lua")
local bc = string.dec(string.dump(func))
print("Original: " .. #bc .. " bytes")

-- 混淆
local protected, pstats = protect(bc)
print("Protected: " .. #protected .. " bytes (" .. pstats.ratio .. ")")
print("Passes: " .. table.concat(pstats.passes, " -> "))

-- 验证混淆后可执行
local ok, f = pcall(load, protected)
print("Protected load: " .. tostring(ok))
if ok then
    local old = print
    print = function() end
    local exec_ok = pcall(f)
    print = old
    print("Protected exec: " .. tostring(exec_ok))
end

-- 去混淆
local cleaned, cstats = deprotect(protected)
print("\nCleaned: " .. #cleaned .. " bytes (" .. cstats.ratio .. ")")
print("Passes: " .. table.concat(cstats.passes, " -> "))
for k, v in pairs(cstats.removed) do
    print("  " .. k .. ": " .. v)
end

-- 验证去混淆后可执行
local ok2, f2 = pcall(load, cleaned)
print("Cleaned load: " .. tostring(ok2))
if ok2 then
    local old = print
    local outputs = {}
    print = function(...) table.insert(outputs, table.concat({...}, "\t")) end
    local exec_ok2, err = pcall(f2)
    print = old
    print("Cleaned exec: " .. tostring(exec_ok2))
    if not exec_ok2 then print("Error: " .. tostring(err)) end
    print("Last output: " .. outputs[#outputs])
end

-- 对比原始和去混淆后的输出
print("\n=== Output comparison ===")
local old = print
local orig_outputs = {}
print = function(...) table.insert(orig_outputs, table.concat({...}, "\t")) end
pcall(load(bc)())
print = old

local clean_outputs = {}
print = function(...) table.insert(clean_outputs, table.concat({...}, "\t")) end
pcall(load(cleaned)())
print = old

print("Original lines: " .. #orig_outputs)
print("Cleaned lines: " .. #clean_outputs)
local match = true
for i = 1, math.max(#orig_outputs, #clean_outputs) do
    if orig_outputs[i] ~= clean_outputs[i] then
        match = false
        print(string.format("  MISMATCH at line %d: '%s' vs '%s'",
            i, tostring(orig_outputs[i]), tostring(clean_outputs[i])))
    end
end
print("Output match: " .. tostring(match))
