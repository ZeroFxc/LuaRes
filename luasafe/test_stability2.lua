-- test_stability2.lua
-- 每次测试前彻底重置环境

local function run_one(seed_val)
    -- 保存原始 package.loaded
    local saved = {}
    for k, v in pairs(package.loaded) do
        saved[k] = v
    end

    -- 清除所有非基础模块
    for k in pairs(package.loaded) do
        if k ~= "luac" and k ~= "_G" and k ~= "io" and k ~= "os" and k ~= "string"
           and k ~= "table" and k ~= "math" and k ~= "coroutine" and k ~= "package"
           and k ~= "debug" and k ~= "utf8" then
            package.loaded[k] = nil
        end
    end

    -- 强制垃圾回收
    collectgarbage("collect")

    local p = require("protect")
    local d = require("deprotect")
    local func = loadfile("test_multi_func.lua")
    local bc = string.dec(string.dump(func))
    local prot = p(bc, {seed = seed_val})
    local clean, stats = d.clean(prot, {})
    local ok, f = pcall(load, clean)
    if not ok then
        return "LOAD_FAIL"
    end
    local old_print = print
    local out = {}
    print = function(...) table.insert(out, table.concat({...}, "\t")) end
    local e, err = pcall(f)
    print = old_print

    -- 恢复 package.loaded
    for k in pairs(package.loaded) do
        if not saved[k] then
            package.loaded[k] = nil
        end
    end
    for k, v in pairs(saved) do
        package.loaded[k] = v
    end

    if e then
        return "PASS"
    else
        return "FAIL: " .. tostring(err)
    end
end

local pass_count = 0
local fail_count = 0
for seed = 1, 20 do
    local result = run_one(seed * 1000 + 7)
    print(string.format("seed %d: %s", seed, result))
    if result == "PASS" then
        pass_count = pass_count + 1
    else
        fail_count = fail_count + 1
    end
end

print(string.format("\nResult: %d pass, %d fail", pass_count, fail_count))
