-- 模块组合边界测试
-- 验证 table_obfuscate 与其他模块组合时的正确性 (正向执行 + 反向还原)
package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"

local luac = require('luac')

math.randomseed(42)

-- 正向模块入口映射 (与 menu.lua 一致)
local FORWARD_FN = {
    bool_obfuscate = 'obfuscate',
    num_obfuscate = 'obfuscate',
    str_split = 'obfuscate',
    str_encrypt = 'encrypt',
    const_shuffle = 'shuffle',
    instruction_mutate = 'process_function',
    table_obfuscate = 'obfuscate',
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

-- 反向模块入口映射
local REVERSE_FN = {
    fix_antidec = 'clean',
    deop48 = 'clean',
    dejunk_jmp = 'clean',
    dejunk_loadk = 'clean',
    dejunk_move = 'clean',
    deopaque_junk = 'clean',
    deconst_poison = 'clean',
    deopaque_predicate = 'clean',
    deinstruction_mutate = 'clean',
    detable_obfuscate = 'clean',
    deconst_shuffle = 'clean',
    denum_obfuscate = 'clean',
    debool_obfuscate = 'clean',
    destr_split = 'clean',
    destr_encrypt = 'clean',
    deflatten = 'clean',
    deprotect = 'clean',
    de_junk_obfuscate = 'clean',
}

-- 正向执行顺序 (与 menu.lua FORWARD_ORDER 一致)
local FORWARD_ORDER = {
    'bool_obfuscate', 'num_obfuscate', 'str_split', 'str_encrypt',
    'const_shuffle', 'instruction_mutate', 'table_obfuscate',
    'opaque_predicate', 'const_poison', 'opaque_junk', 'junk_jmp',
    'junk_loadk', 'junk_move', 'op48_junk',
    'luac_obfuscate', 'luac_flatten', 'debug_strip', 'antidec',
}

-- 反向执行顺序
local REVERSE_ORDER = {
    'fix_antidec', 'deop48', 'dejunk_jmp', 'dejunk_loadk', 'dejunk_move',
    'deopaque_junk', 'deconst_poison', 'deopaque_predicate',
    'deinstruction_mutate', 'detable_obfuscate', 'deconst_shuffle',
    'denum_obfuscate', 'debool_obfuscate', 'destr_split', 'destr_encrypt',
    'deflatten', 'deprotect', 'de_junk_obfuscate',
}

local loaded_forward = {}
local loaded_reverse = {}

local function get_forward_fn(name)
    if not loaded_forward[name] then
        local ok, mod = pcall(require, name)
        if not ok then return nil, mod end
        loaded_forward[name] = mod
    end
    local fn_name = FORWARD_FN[name]
    return loaded_forward[name][fn_name]
end

local function get_reverse_fn(name)
    if not loaded_reverse[name] then
        local ok, mod = pcall(require, name)
        if not ok then return nil, mod end
        loaded_reverse[name] = mod
    end
    local fn_name = REVERSE_FN[name]
    return loaded_reverse[name][fn_name]
end

local function compile(src)
    local func = load(src)
    local shell = string.dump(func)
    local bc = string.dec(shell)
    return luac.undump(bc, false)
end

local function run_proto(proto)
    local bc = luac.dump(proto)
    local func = load(bc)
    return func()
end

-- 按 FORWARD_ORDER 顺序执行选中的模块
local function run_forward(proto, selected_set)
    local results = {}
    for _, name in ipairs(FORWARD_ORDER) do
        if selected_set[name] then
            local fn, err = get_forward_fn(name)
            if not fn then
                results[name] = 'LOAD_FAIL:' .. tostring(err)
            else
                local ok, n = pcall(fn, proto, {})
                if ok then
                    results[name] = tonumber(n) or 0
                else
                    results[name] = 'ERROR:' .. tostring(n)
                end
            end
        end
    end
    return results
end

-- 按 REVERSE_ORDER 顺序执行对应的反向模块
local function run_reverse(proto, forward_selected)
    local reverse_map = {
        antidec = 'fix_antidec',
        op48_junk = 'deop48',
        junk_jmp = 'dejunk_jmp',
        junk_loadk = 'dejunk_loadk',
        junk_move = 'dejunk_move',
        opaque_junk = 'deopaque_junk',
        const_poison = 'deconst_poison',
        opaque_predicate = 'deopaque_predicate',
        instruction_mutate = 'deinstruction_mutate',
        table_obfuscate = 'detable_obfuscate',
        const_shuffle = 'deconst_shuffle',
        num_obfuscate = 'denum_obfuscate',
        bool_obfuscate = 'debool_obfuscate',
        str_split = 'destr_split',
        str_encrypt = 'destr_encrypt',
        luac_flatten = 'deflatten',
    }
    local selected = {}
    for fwd, rev in pairs(reverse_map) do
        if forward_selected[fwd] then
            selected[rev] = true
        end
    end
    -- 始终运行综合去保护和去垃圾
    selected['deprotect'] = true
    selected['de_junk_obfuscate'] = true

    local results = {}
    for _, name in ipairs(REVERSE_ORDER) do
        if selected[name] then
            local fn, err = get_reverse_fn(name)
            if not fn then
                results[name] = 'LOAD_FAIL:' .. tostring(err)
            else
                local ok, n = pcall(fn, proto, {})
                if ok then
                    results[name] = tonumber(n) or 0
                else
                    results[name] = 'ERROR:' .. tostring(n)
                end
            end
        end
    end
    return results
end

-- ============================================================
-- 测试用例
-- ============================================================
local TESTS = {
    {
        name = '基础表读写',
        src = [[
            local t = {a=1, b=2, c=3}
            t.d = 4
            t["e"] = 5
            return t.a + t.b + t.c + t.d + t.e
        ]],
        expect = 15,
    },
    {
        name = '数组混合',
        src = [[
            local t = {10, 20, x=30, 40, y=50}
            return t[1] + t[2] + t[3] + t.x + t.y
        ]],
        expect = 150,
    },
    {
        name = '嵌套表',
        src = [[
            local t = {a={b={c=42}}}
            return t.a.b.c
        ]],
        expect = 42,
    },
    {
        name = '方法调用',
        src = [[
            local t = {val=100}
            function t:add(n) return self.val + n end
            return t:add(50)
        ]],
        expect = 150,
    },
    {
        name = '循环表操作',
        src = [[
            local t = {}
            for i=1,50 do t[i] = i * 2 end
            local s = 0
            for i=1,50 do s = s + t[i] end
            return s
        ]],
        expect = 2550,
    },
    {
        name = '条件表操作',
        src = [[
            local t = {x=10, y=20}
            local r = 0
            if t.x > 5 then r = r + t.y end
            if t.y < 10 then r = r + 100 else r = r + t.x end
            for k,v in pairs(t) do r = r + v end
            return r
        ]],
        expect = 10 + 20 + 10 + 20,
    },
    {
        name = 'upvalue表',
        src = [[
            local t = {count=0}
            local function inc() t.count = t.count + 1 end
            inc(); inc(); inc()
            return t.count
        ]],
        expect = 3,
    },
    {
        name = '字符串键',
        src = [[
            local t = {}
            t["hello world"] = 1
            t["a.b.c"] = 2
            t[""] = 3
            return t["hello world"] + t["a.b.c"] + t[""]
        ]],
        expect = 6,
    },
    {
        name = '复杂混合',
        src = [[
            local t = {items={}, meta={version=1}}
            table.insert(t.items, {id=1, name="a"})
            table.insert(t.items, {id=2, name="b"})
            t.meta.count = #t.items
            local r = t.meta.version
            for i=1,#t.items do r = r + t.items[i].id end
            return r + t.meta.count
        ]],
        expect = 1 + 1 + 2 + 2,
    },
    {
        name = '表作为函数参数',
        src = [[
            local function sum(t)
                local s = 0
                for i=1,#t do s = s + t[i] end
                return s
            end
            return sum({1,2,3,4,5})
        ]],
        expect = 15,
    },
}

-- ============================================================
-- 组合定义: 每个组合是一组正向模块名
-- ============================================================
local COMBOS = {
    { name = 'table_only',         mods = {'table_obfuscate'} },
    { name = 'table+instr_mut',    mods = {'table_obfuscate', 'instruction_mutate'} },
    { name = 'table+const_shuffle',mods = {'table_obfuscate', 'const_shuffle'} },
    { name = 'table+const_poison', mods = {'table_obfuscate', 'const_poison'} },
    { name = 'table+bool',         mods = {'table_obfuscate', 'bool_obfuscate'} },
    { name = 'table+num',          mods = {'table_obfuscate', 'num_obfuscate'} },
    { name = 'table+junk_jmp',     mods = {'table_obfuscate', 'junk_jmp'} },
    { name = 'table+junk_loadk',   mods = {'table_obfuscate', 'junk_loadk'} },
    { name = 'table+junk_move',    mods = {'table_obfuscate', 'junk_move'} },
    { name = 'table+opaque_pred',  mods = {'table_obfuscate', 'opaque_predicate'} },
    { name = 'table+opaque_junk',  mods = {'table_obfuscate', 'opaque_junk'} },
    { name = 'table+str_encrypt',  mods = {'table_obfuscate', 'str_encrypt'} },
    { name = 'table+str_split',    mods = {'table_obfuscate', 'str_split'} },
    { name = 'table+op48',         mods = {'table_obfuscate', 'op48_junk'} },
    { name = 'table+luac_obf',     mods = {'table_obfuscate', 'luac_obfuscate'} },
    { name = 'table+flatten',      mods = {'table_obfuscate', 'luac_flatten'} },
    { name = 'table+debug_strip',  mods = {'table_obfuscate', 'debug_strip'} },
    { name = 'table+antidec',      mods = {'table_obfuscate', 'antidec'} },
    { name = 'triple:tbl+instr+bool', mods = {'table_obfuscate', 'instruction_mutate', 'bool_obfuscate'} },
    { name = 'triple:tbl+shuffle+poison', mods = {'table_obfuscate', 'const_shuffle', 'const_poison'} },
    { name = 'triple:tbl+junk_all', mods = {'table_obfuscate', 'junk_jmp', 'junk_loadk', 'junk_move'} },
    { name = 'quad:tbl+instr+bool+num', mods = {'table_obfuscate', 'instruction_mutate', 'bool_obfuscate', 'num_obfuscate'} },
    { name = 'all_junk+table',     mods = {'table_obfuscate', 'opaque_junk', 'junk_jmp', 'junk_loadk', 'junk_move', 'op48_junk', 'const_poison'} },
    { name = 'all_forward',        mods = FORWARD_ORDER },
}

local total_tests = 0
local pass_fwd = 0
local pass_rev = 0
local failures = {}

for _, combo in ipairs(COMBOS) do
    local selected = {}
    for _, m in ipairs(combo.mods) do selected[m] = true end

    for _, test in ipairs(TESTS) do
        total_tests = total_tests + 1
        local proto = compile(test.src)
        local orig_code = #proto.code

        -- 正向
        local fwd_results = run_forward(proto, selected)
        local fwd_errors = {}
        for name, r in pairs(fwd_results) do
            if type(r) == 'string' and r:match('ERROR') then
                table.insert(fwd_errors, name .. '=' .. r)
            end
        end

        local fwd_ok, fwd_result = pcall(run_proto, proto)
        local fwd_pass = fwd_ok and fwd_result == test.expect

        if not fwd_pass then
            table.insert(failures, {
                combo = combo.name, test = test.name, phase = 'forward',
                detail = fwd_ok and ('result=' .. tostring(fwd_result) .. ' expect=' .. tostring(test.expect))
                         or ('exec_error: ' .. tostring(fwd_result)),
                fwd_errors = fwd_errors,
            })
        else
            pass_fwd = pass_fwd + 1
        end

        -- 反向 (仅在正向成功时测试)
        if fwd_pass then
            local rev_results = run_reverse(proto, selected)
            local rev_errors = {}
            for name, r in pairs(rev_results) do
                if type(r) == 'string' and r:match('ERROR') then
                    table.insert(rev_errors, name .. '=' .. r)
                end
            end

            local rev_ok, rev_result = pcall(run_proto, proto)
            local rev_pass = rev_ok and rev_result == test.expect

            if not rev_pass then
                table.insert(failures, {
                    combo = combo.name, test = test.name, phase = 'reverse',
                    detail = rev_ok and ('result=' .. tostring(rev_result) .. ' expect=' .. tostring(test.expect))
                             or ('exec_error: ' .. tostring(rev_result)),
                    rev_errors = rev_errors,
                })
            else
                pass_rev = pass_rev + 1
            end
        end
    end
end

-- 报告
print(string.format('=== 组合边界测试: %d 组合 x %d 用例 = %d 轮 ===', #COMBOS, #TESTS, total_tests))
print(string.format('正向通过: %d/%d', pass_fwd, total_tests))
print(string.format('反向通过: %d/%d', pass_rev, pass_fwd))
print()

if #failures > 0 then
    print('=== 失败详情 ===')
    for i, f in ipairs(failures) do
        print(string.format('[%d] %s | %s | %s', i, f.combo, f.test, f.phase))
        print('    ' .. f.detail)
        if f.fwd_errors and #f.fwd_errors > 0 then
            print('    fwd_errors: ' .. table.concat(f.fwd_errors, ', '))
        end
        if f.rev_errors and #f.rev_errors > 0 then
            print('    rev_errors: ' .. table.concat(f.rev_errors, ', '))
        end
    end
else
    print('全部通过!')
end

os.exit(#failures > 0 and 1 or 0)
