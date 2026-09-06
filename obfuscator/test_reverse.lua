-- test_reverse.lua: 测试所有反向去混淆模块的 round-trip
package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/reverse/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')

local function compile_source(src)
    local func = load(src)
    local dumped = string.dump(func)
    local bc = string.dec(dumped)
    return luac.undump(bc, false)
end

local function run_proto(proto)
    local bc = luac.dump(proto)
    local func = load(bc)
    local results = {}
    local old_print = print
    print = function(...)
        local p = {}
        for i = 1, select('#', ...) do p[i] = tostring(select(i, ...)) end
        table.insert(results, table.concat(p, '\t'))
    end
    local ok, err = pcall(func)
    print = old_print
    if not ok then return nil, err end
    return table.concat(results, '\n')
end

local function test_module(name, obf_module, deobf_module, src, obf_fn, deobf_fn, obf_opt, deobf_opt)
    io.write(string.format("[%s] ", name))
    obf_fn = obf_fn or 'obfuscate'
    deobf_fn = deobf_fn or 'clean'
    local proto = compile_source(src)
    local original_output, err1 = run_proto(proto)
    if not original_output then
        print("ORIGINAL_FAIL: " .. tostring(err1))
        return false
    end

    -- 正向混淆
    local proto2 = compile_source(src)
    local ok2, err2 = pcall(function()
        obf_module[obf_fn](proto2, obf_opt or {})
    end)
    if not ok2 then
        print("OBF_FAIL: " .. tostring(err2))
        return false
    end
    local obf_output, err3 = run_proto(proto2)
    if not obf_output then
        print("OBF_RUN_FAIL: " .. tostring(err3))
        return false
    end
    if obf_output ~= original_output then
        print("OBF_OUTPUT_MISMATCH")
        print("  original: " .. original_output)
        print("  obf:      " .. obf_output)
        return false
    end

    -- 反向去混淆
    local ok3, err4 = pcall(function()
        deobf_module[deobf_fn](proto2, deobf_opt or {})
    end)
    if not ok3 then
        print("DEOBF_FAIL: " .. tostring(err4))
        return false
    end
    local deobf_output, err5 = run_proto(proto2)
    if not deobf_output then
        print("DEOBF_RUN_FAIL: " .. tostring(err5))
        return false
    end
    if deobf_output ~= original_output then
        print("DEOBF_OUTPUT_MISMATCH")
        print("  original: " .. original_output)
        print("  deobf:    " .. deobf_output)
        return false
    end

    print("PASS")
    return true
end

local pass = 0
local fail = 0

-- 1. const_poison
do
    local const_poison = require('const_poison')
    local deconst_poison = require('deconst_poison')
    if test_module("const_poison", const_poison, deconst_poison,
        "print('hello'); print(123); local t={a=1}; print(t.a)",
        "poison", "clean") then
        pass = pass + 1 else fail = fail + 1 end
end

-- 2. num_obfuscate
do
    local num_obf = require('num_obfuscate')
    local denum = require('denum_obfuscate')
    if test_module("num_obfuscate", num_obf, denum,
        "local a=42; local b=100; print(a+b); print(a*b); print(b-a)") then
        pass = pass + 1 else fail = fail + 1 end
end

-- 3. bool_obfuscate
do
    local bool_obf = require('bool_obfuscate')
    local debool = require('debool_obfuscate')
    if test_module("bool_obfuscate", bool_obf, debool,
        "local a=true; local b=false; print(a); print(b); print(a and b); print(a or b); if a then print('yes') end") then
        pass = pass + 1 else fail = fail + 1 end
end

-- 4. str_split
do
    local str_split = require('str_split')
    local destr_split = require('destr_split')
    if test_module("str_split", str_split, destr_split,
        "local s='hello world'; print(s); local t={key='value'}; print(t.key); print(t['key'])") then
        pass = pass + 1 else fail = fail + 1 end
end

-- 5. str_encrypt
do
    local str_enc = require('str_encrypt')
    local destr_enc = require('destr_encrypt')
    if test_module("str_encrypt", str_enc, destr_enc,
        "local s='hello world'; print(s); local t={key='value'}; print(t.key); print(t['key'])",
        "encrypt", "clean") then
        pass = pass + 1 else fail = fail + 1 end
end

print(string.format("\n=== Result: %d pass, %d fail ===", pass, fail))
