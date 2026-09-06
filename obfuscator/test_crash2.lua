package.path = package.path .. ";E:/LuaRes/luatools/?.lua"
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

print("step1: require modules")
local str_enc = require('str_encrypt')
local destr_enc = require('destr_encrypt')
local src = "local s='hello world'; print(s); local t={key='value'}; print(t.key); print(t['key'])"

print("step2: compile original")
local proto = compile_source(src)
print("step3: run original")
local original_output = run_proto(proto)
print("original: " .. tostring(original_output))

print("step4: compile proto2")
local proto2 = compile_source(src)
print("step5: encrypt")
str_enc.encrypt(proto2, {})
print("step6: run obf")
local obf_output = run_proto(proto2)
print("obf: " .. tostring(obf_output))

print("step7: clean")
destr_enc.clean(proto2)
print("step8: dump")
local bc = luac.dump(proto2)
print("step9: load")
local func = load(bc)
print("step10: run")
func()
print("DONE")
