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

local str_enc = require('str_encrypt')
local destr_enc = require('destr_encrypt')
local src = "local s='hello world'; print(s); local t={key='value'}; print(t.key); print(t['key'])"

local proto = compile_source(src)
local original_output = run_proto(proto)
print("original: " .. tostring(original_output))

local proto2 = compile_source(src)
str_enc.encrypt(proto2, {})
local obf_output = run_proto(proto2)
print("obf: " .. tostring(obf_output))

destr_enc.clean(proto2)
local deobf_output = run_proto(proto2)
print("deobf: " .. tostring(deobf_output))
print("DONE")
