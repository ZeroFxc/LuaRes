-- 反向还原组合测试: 正向混淆后应用对应反向模块, 验证可还原
package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')

-- 正向模块 -> 反向模块映射 (有反向对应的)
local PAIRS = {
    {fwd='table_obfuscate', fwd_entry='obfuscate', rev='detable_obfuscate', rev_entry='clean'},
    {fwd='instruction_mutate', fwd_entry='process_function', rev='deinstruction_mutate', rev_entry='clean'},
    {fwd='const_shuffle', fwd_entry='shuffle', rev='deconst_shuffle', rev_entry='clean'},
    {fwd='str_encrypt', fwd_entry='encrypt', rev='destr_encrypt', rev_entry='decrypt'},
    {fwd='bool_obfuscate', fwd_entry='obfuscate', rev='debool_obfuscate', rev_entry='clean'},
    {fwd='num_obfuscate', fwd_entry='obfuscate', rev='denum_obfuscate', rev_entry='clean'},
}

local loaded = {}
local function get_mod(name)
    if not loaded[name] then
        local ok, mod = pcall(require, name)
        if not ok then return nil end
        loaded[name] = mod
    end
    return loaded[name]
end

local TESTS = {
    {name='基础', src='local t={a=1,b=2} t.c=3 return t.a+t.b+t.c', expect=6},
    {name='方法', src='local t={v=10} function t:f(n) return self.v+n end return t:f(5)', expect=15},
    {name='upvalue', src='local t={c=0} local function inc() t.c=t.c+1 end inc() inc() return t.c', expect=2},
    {name='嵌套', src='local t={a={b=42}} return t.a.b', expect=42},
}

local COMBOS = {
    {'table_only', {'table_obfuscate'}},
    {'tbl+instr', {'table_obfuscate','instruction_mutate'}},
    {'tbl+shuffle', {'table_obfuscate','const_shuffle'}},
    {'tbl+strenc', {'table_obfuscate','str_encrypt'}},
    {'tbl+bool', {'table_obfuscate','bool_obfuscate'}},
    {'tbl+num', {'table_obfuscate','num_obfuscate'}},
    {'tbl+instr+bool', {'table_obfuscate','instruction_mutate','bool_obfuscate'}},
}

local pass, fail = 0, 0
for _, combo in ipairs(COMBOS) do
    local cname, cmods = combo[1], combo[2]
    for _, test in ipairs(TESTS) do
        math.randomseed(42)
        local proto = luac.undump(string.dec(string.dump(load(test.src))), false)
        local orig_code = #proto.code
        -- 正向
        for _, pair in ipairs(PAIRS) do
            for _, m in ipairs(cmods) do
                if m == pair.fwd then
                    local mod = get_mod(pair.fwd)
                    if mod then pcall(mod[pair.fwd_entry], proto, {}) end
                end
            end
        end
        -- 反向 (逆序)
        for i = #PAIRS, 1, -1 do
            local pair = PAIRS[i]
            for _, m in ipairs(cmods) do
                if m == pair.fwd then
                    local mod = get_mod(pair.rev)
                    if mod then pcall(mod[pair.rev_entry], proto, {}) end
                end
            end
        end
        local ok, result = pcall(function() return load(luac.dump(proto))() end)
        local status = ok and result == test.expect
        if status then pass = pass + 1
        else
            fail = fail + 1
            print(string.format('FAIL %-18s | %-8s exec=%s result=%s', cname, test.name,
                tostring(ok), tostring(result):sub(1,40)))
        end
    end
end
print(string.format('=== reverse combo: %d pass, %d fail ===', pass, fail))
