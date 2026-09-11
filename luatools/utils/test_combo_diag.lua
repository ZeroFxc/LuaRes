-- 组合边界测试 - 诊断版: 逐个打印进度, 定位崩溃点
package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"

local luac = require('luac')
math.randomseed(42)

local FORWARD_FN = {
    bool_obfuscate = 'obfuscate', num_obfuscate = 'obfuscate',
    str_split = 'obfuscate', str_encrypt = 'encrypt',
    const_shuffle = 'shuffle', instruction_mutate = 'process_function',
    table_obfuscate = 'obfuscate', opaque_predicate = 'process_function',
    const_poison = 'poison', opaque_junk = 'inject',
    junk_jmp = 'inject', junk_loadk = 'inject', junk_move = 'inject',
    op48_junk = 'inject', luac_obfuscate = 'obfuscate_proto',
    luac_flatten = 'flatten_proto', debug_strip = 'strip', antidec = 'protect',
}
local FORWARD_ORDER = {
    'bool_obfuscate', 'num_obfuscate', 'str_split', 'str_encrypt',
    'const_shuffle', 'instruction_mutate', 'table_obfuscate',
    'opaque_predicate', 'const_poison', 'opaque_junk', 'junk_jmp',
    'junk_loadk', 'junk_move', 'op48_junk',
    'luac_obfuscate', 'luac_flatten', 'debug_strip', 'antidec',
}
local loaded = {}
local function get_fn(name)
    if not loaded[name] then
        local ok, mod = pcall(require, name)
        if not ok then return nil, mod end
        loaded[name] = mod
    end
    return loaded[name][FORWARD_FN[name]]
end

local function compile(src)
    local func = load(src)
    return luac.undump(string.dec(string.dump(func)), false)
end
local function run_proto(proto)
    return load(luac.dump(proto))()
end

local TESTS = {
    {name='基础', src='local t={a=1,b=2} t.c=3 return t.a+t.b+t.c', expect=6},
    {name='数组', src='local t={1,2,3} return t[1]+t[2]+t[3]', expect=6},
    {name='嵌套', src='local t={a={b=42}} return t.a.b', expect=42},
    {name='方法', src='local t={v=10} function t:f(n) return self.v+n end return t:f(5)', expect=15},
    {name='循环', src='local t={} for i=1,20 do t[i]=i end local s=0 for i=1,20 do s=s+t[i] end return s', expect=210},
    {name='upvalue', src='local t={c=0} local function inc() t.c=t.c+1 end inc() inc() return t.c', expect=2},
    {name='条件', src='local t={x=10} local r=0 if t.x>5 then r=t.x*2 end return r', expect=20},
}

local COMBOS = {
    {'table_only', {'table_obfuscate'}},
    {'tbl+instr', {'table_obfuscate','instruction_mutate'}},
    {'tbl+shuffle', {'table_obfuscate','const_shuffle'}},
    {'tbl+poison', {'table_obfuscate','const_poison'}},
    {'tbl+bool', {'table_obfuscate','bool_obfuscate'}},
    {'tbl+num', {'table_obfuscate','num_obfuscate'}},
    {'tbl+jmp', {'table_obfuscate','junk_jmp'}},
    {'tbl+loadk', {'table_obfuscate','junk_loadk'}},
    {'tbl+move', {'table_obfuscate','junk_move'}},
    {'tbl+opred', {'table_obfuscate','opaque_predicate'}},
    {'tbl+ojunk', {'table_obfuscate','opaque_junk'}},
    {'tbl+strenc', {'table_obfuscate','str_encrypt'}},
    {'tbl+strsplit', {'table_obfuscate','str_split'}},
    {'tbl+op48', {'table_obfuscate','op48_junk'}},
    {'tbl+luacobf', {'table_obfuscate','luac_obfuscate'}},
    {'tbl+flatten', {'table_obfuscate','luac_flatten'}},
    {'tbl+dbgstrip', {'table_obfuscate','debug_strip'}},
    {'tbl+antidec', {'table_obfuscate','antidec'}},
    {'tbl+instr+bool', {'table_obfuscate','instruction_mutate','bool_obfuscate'}},
    {'tbl+shuffle+poison', {'table_obfuscate','const_shuffle','const_poison'}},
    {'tbl+junk3', {'table_obfuscate','junk_jmp','junk_loadk','junk_move'}},
    {'tbl+instr+bool+num', {'table_obfuscate','instruction_mutate','bool_obfuscate','num_obfuscate'}},
    {'tbl+alljunk', {'table_obfuscate','opaque_junk','junk_jmp','junk_loadk','junk_move','op48_junk','const_poison'}},
    {'all', FORWARD_ORDER},
}

for ci, combo in ipairs(COMBOS) do
    local cname, cmods = combo[1], combo[2]
    local sel = {}
    for _, m in ipairs(cmods) do sel[m] = true end
    for ti, test in ipairs(TESTS) do
        io.write(string.format('[%02d/%02d] %-20s | %-8s ... ', ci, #COMBOS, cname, test.name))
        io.flush()
        local proto = compile(test.src)
        local errs = {}
        for _, name in ipairs(FORWARD_ORDER) do
            if sel[name] then
                local fn = get_fn(name)
                if fn then
                    local ok, n = pcall(fn, proto, {})
                    if not ok then
                        table.insert(errs, name .. ':' .. tostring(n):sub(1, 60))
                    end
                end
            end
        end
        local ok, result = pcall(run_proto, proto)
        if not ok then
            print('CRASH/EXEC_ERR: ' .. tostring(result):sub(1, 80))
            if #errs > 0 then print('    module errors: ' .. table.concat(errs, '; ')) end
        elseif result ~= test.expect then
            print(string.format('FAIL result=%s expect=%s', tostring(result), tostring(test.expect)))
            if #errs > 0 then print('    module errors: ' .. table.concat(errs, '; ')) end
        else
            print('OK')
        end
    end
end
print('DONE')
