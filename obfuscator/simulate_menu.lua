package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"

local luac = require('luac')

-- 完全复制 menu.lua 的 compile_source
local function compile_source(data)
    local func, err = load(data)
    if func then
        local bc = string.dec(string.dump(func))
        return luac.undump(bc, false)
    end
    local ok, dec = pcall(string.dec, data)
    if ok and dec and #dec > 0 then
        local ok2, proto = pcall(luac.undump, dec, false)
        if ok2 and proto then return proto end
    end
    local ok3, proto2 = pcall(luac.undump, data, false)
    if ok3 and proto2 then return proto2 end
    error('无法解析输入')
end

-- menu.lua 的 FORWARD_FN 映射
local FORWARD_FN = {
    bool_obfuscate = 'obfuscate',
    num_obfuscate = 'obfuscate',
    str_split = 'obfuscate',
    str_encrypt = 'encrypt',
    const_shuffle = 'shuffle',
    instruction_mutate = 'process_function',
    opaque_predicate = 'process_function',
    const_poison = 'poison',
    opaque_junk = 'inject',
    junk_jmp = 'inject',
    junk_loadk = 'inject',
    junk_move = 'inject',
    op48_junk = 'inject',
    luac_obfuscate = 'obfuscate_proto',
    luac_flatten = 'flatten_proto',
    debug_strip = 'strip',
    antidec = 'protect',
}

local f = io.open('C:/Users/ruilo/Downloads/tk.lua', 'rb')
local data = f:read('*a'); f:close()
print('input size:', #data, 'first:', string.byte(data,1))

local proto = compile_source(data)
print('compile_source: main sc='..proto.sizecode..' sk='..#proto.k..' sp='..#proto.p)

-- menu.lua 的模块顺序（用户勾选的）
local modules = {'bool_obfuscate','num_obfuscate','str_split','const_shuffle','opaque_predicate','op48_junk','debug_strip','antidec'}

for _, name in ipairs(modules) do
    local mod = require(name)
    local fn_name = FORWARD_FN[name]
    local fn = mod[fn_name]
    local ok, n = pcall(fn, proto, {})
    n = tonumber(n) or 0
    -- 每步都 dump 看大小
    local out = luac.dump(proto)
    print(string.format('%-20s fn=%-18s changes=%-6d dump=%-8d sk=%d sp=%d',
        name, fn_name, n, #out, #proto.k, #proto.p))
end

local final = luac.dump(proto)
print('FINAL dump size:', #final)
local func, err = load(final)
print('load:', func and 'OK' or ('FAIL: '..tostring(err):sub(1,80)))
