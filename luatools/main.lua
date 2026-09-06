-- luatools/main.lua - 字节码混淆/去混淆 CLI 主入口
-- 用法:
--   lua main.lua --list                    列出所有模块
--   lua main.lua input.lua output.luac     用默认模块混淆
--   lua main.lua input.lua output.luac --all            开启所有正向模块
--   lua main.lua input.lua output.luac -m str_encrypt -m bool_obfuscate
--   lua main.lua input.luac output.lua --deobf --all   去混淆模式
--   lua main.lua input.lua output.luac --no str_encrypt  排除指定模块

package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"

local luac = require('luac')

local FORWARD_DIR = 'E:/LuaRes/luatools/forward'
local REVERSE_DIR = 'E:/LuaRes/luatools/reverse'

-- 模块执行顺序（正向）
local FORWARD_ORDER = {
    'bool_obfuscate', 'num_obfuscate', 'str_split',
    'const_shuffle', 'instruction_mutate', 'opaque_predicate',
    'const_poison', 'opaque_junk', 'junk_jmp', 'junk_loadk',
    'junk_move', 'op48_junk',
    'luac_obfuscate', 'luac_flatten', 'debug_strip',
    'antidec',
}

-- 模块执行顺序（反向）
local REVERSE_ORDER = {
    'fix_antidec', 'deop48', 'dejunk_jmp', 'dejunk_loadk',
    'dejunk_move', 'deopaque_junk', 'deconst_poison',
    'deopaque_predicate', 'deinstruction_mutate',
    'deconst_shuffle', 'denum_obfuscate', 'debool_obfuscate',
    'destr_split', 'destr_encrypt',
    'deflatten', 'dedebug_strip', 'deprotect',
    'de_junk_obfuscate',
}

local DEFAULT_FORWARD = {
    'bool_obfuscate', 'num_obfuscate', 'str_split',
    'const_shuffle', 'opaque_predicate', 'op48_junk',
    'debug_strip', 'antidec',
}

local function list_modules(deobf)
    local order = deobf and REVERSE_ORDER or FORWARD_ORDER
    local list = {}
    for _, m in ipairs(order) do list[#list + 1] = m end
    table.sort(list)
    return list
end

local function parse_args(args)
    local opts = {
        modules = {}, exclude = {},
        deobf = false, all = false, list = false,
        input = nil, output = nil,
    }
    local i = 1
    while i <= #args do
        local a = args[i]
        if a == '--list' then opts.list = true
        elseif a == '--deobf' then opts.deobf = true
        elseif a == '--all' then opts.all = true
        elseif a == '-m' or a == '--module' then
            i = i + 1; opts.modules[#opts.modules + 1] = args[i]
        elseif a:match('^%-m=(.+)$') then
            opts.modules[#opts.modules + 1] = a:match('^%-m=(.+)$')
        elseif a == '--no' then
            i = i + 1; opts.exclude[#opts.exclude + 1] = args[i]
        elseif a:match('^%-%-no=(.+)$') then
            opts.exclude[#opts.exclude + 1] = a:match('^%-%-no=(.+)$')
        elseif not a:match('^%-') then
            if not opts.input then opts.input = a
            elseif not opts.output then opts.output = a
            end
        end
        i = i + 1
    end
    return opts
end

local function load_module(name, deobf)
    local dir = deobf and REVERSE_DIR or FORWARD_DIR
    local path = dir .. '/' .. name .. '.lua'
    local f = io.open(path, 'r')
    if not f then return nil, 'module not found: ' .. name end
    f:close()
    local ok, mod = pcall(require, name)
    if not ok then return nil, 'load failed: ' .. tostring(mod) end
    return mod
end

local function get_fn(mod, deobf)
    if deobf then
        return mod.clean or mod.deobfuscate or mod.run
    else
        return mod.encrypt or mod.obfuscate or mod.run or mod.protect
    end
end

local function compile_source(src)
    local func = load(src)
    local bc = string.dec(string.dump(func))
    return luac.undump(bc, false)
end

local function main()
    local args = arg or {}
    local opts = parse_args(args)

    if opts.list then
        print('=== 正向混淆模块 (forward) ===')
        for _, m in ipairs(list_modules(false)) do
            print('  ' .. m)
        end
        print('=== 反向去混淆模块 (reverse) ===')
        for _, m in ipairs(list_modules(true)) do
            print('  ' .. m)
        end
        return
    end

    if not opts.input then
        print('用法: lua main.lua <input> <output> [options]')
        print('  --list              列出所有模块')
        print('  --all               开启所有模块')
        print('  -m <name>           开启指定模块 (可多次)')
        print('  --no <name>         排除指定模块 (可多次)')
        print('  --deobf             去混淆模式')
        print('默认正向模块: ' .. table.concat(DEFAULT_FORWARD, ', '))
        return
    end

    local output = opts.output or (opts.input:gsub('%.lua$', '') .. '_obf.luac')

    -- 确定要执行的模块列表
    local order = opts.deobf and REVERSE_ORDER or FORWARD_ORDER
    local selected = {}
    local exclude_set = {}
    for _, e in ipairs(opts.exclude) do exclude_set[e] = true end

    if opts.all then
        for _, m in ipairs(order) do
            if not exclude_set[m] then selected[#selected + 1] = m end
        end
    elseif #opts.modules > 0 then
        for _, m in ipairs(opts.modules) do
            if not exclude_set[m] then selected[#selected + 1] = m end
        end
    else
        for _, m in ipairs(DEFAULT_FORWARD) do
            if not exclude_set[m] then selected[#selected + 1] = m end
        end
    end

    -- 读取输入
    local fin = io.open(opts.input, 'rb')
    if not fin then print('ERROR: cannot open ' .. opts.input); return end
    local data = fin:read('*a')
    fin:close()

    local proto
    if opts.deobf then
        -- 输入是字节码
        proto = luac.undump(data, false)
    else
        -- 输入是源码
        proto = compile_source(data)
    end

    print(string.format('输入: %s (%d bytes)', opts.input, #data))
    print(string.format('模式: %s', opts.deobf and '去混淆' or '混淆'))
    print(string.format('模块 (%d): %s', #selected, table.concat(selected, ', ')))
    print('---')

    local total = 0
    for _, name in ipairs(selected) do
        local mod, err = load_module(name, opts.deobf)
        if not mod then
            print(string.format('  [SKIP] %s: %s', name, err))
        else
            local fn = get_fn(mod, opts.deobf)
            if not fn then
                print(string.format('  [SKIP] %s: no entry function', name))
            else
                local ok, n = pcall(fn, proto, {})
                if ok then
                    n = tonumber(n) or 0
                    total = total + n
                    print(string.format('  [OK]   %s (%d changes)', name, n))
                else
                    print(string.format('  [FAIL] %s: %s', name, tostring(n)))
                end
            end
        end
    end

    -- 输出
    local out_bc = luac.dump(proto)
    local fout = io.open(output, 'wb')
    if not fout then print('ERROR: cannot write ' .. output); return end
    fout:write(out_bc)
    fout:close()

    print('---')
    print(string.format('输出: %s (%d bytes)', output, #out_bc))
    print(string.format('总计变更: %d', total))
end

main()
