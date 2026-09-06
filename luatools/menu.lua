-- luatools/menu.lua - 交互式菜单版字节码混淆/去混淆工具
-- 用法: lua_luac2.exe menu.lua

os.execute("chcp 65001 >nul 2>nul")

package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"

local luac = require('luac')

local FORWARD_ORDER = {
    'bool_obfuscate', 'num_obfuscate', 'str_split', 'str_encrypt',
    'const_shuffle', 'instruction_mutate', 'opaque_predicate',
    'const_poison', 'opaque_junk', 'junk_jmp', 'junk_loadk',
    'junk_move', 'op48_junk',
    'luac_obfuscate', 'luac_flatten', 'debug_strip',
    'antidec',
}

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

local function clear_screen()
    io.write('\27[2J\27[H')
end

local function print_header(title)
    print('========================================')
    print('  ' .. title)
    print('========================================')
end

local function ask(prompt)
    io.write(prompt)
    io.flush()
    return io.read('*l')
end

local function mode_menu()
    clear_screen()
    print_header('选择模式')
    print('  [1] 混淆 (正向)')
    print('  [2] 去混淆 (反向)')
    print('  [0] 退出')
    print()
    local choice = ask('请选择: ')
    if choice == '1' then return 'forward'
    elseif choice == '2' then return 'reverse'
    elseif choice == '0' then os.exit(0)
    else return mode_menu() end
end

local function module_menu(mode)
    local order = (mode == 'forward') and FORWARD_ORDER or REVERSE_ORDER
    local selected = {}
    local default_set = {}
    if mode == 'forward' then
        for _, m in ipairs(DEFAULT_FORWARD) do default_set[m] = true end
    end
    for _, m in ipairs(order) do selected[m] = default_set[m] or false end

    while true do
        clear_screen()
        print_header((mode == 'forward') and '选择混淆模块' or '选择去混淆模块')
        for i, m in ipairs(order) do
            local mark = selected[m] and '[x]' or '[ ]'
            print(string.format('  %2d. %s %s', i, mark, m))
        end
        print()
        print('  a. 全选    n. 全不选    i. 反选    d. 恢复默认')
        print('  输入数字切换单个模块, 直接回车确认')
        print()
        local choice = ask('选择: ')
        if choice == '' then
            local list = {}
            for _, m in ipairs(order) do
                if selected[m] then list[#list + 1] = m end
            end
            return list
        elseif choice == 'a' then
            for _, m in ipairs(order) do selected[m] = true end
        elseif choice == 'n' then
            for _, m in ipairs(order) do selected[m] = false end
        elseif choice == 'i' then
            for _, m in ipairs(order) do selected[m] = not selected[m] end
        elseif choice == 'd' then
            for _, m in ipairs(order) do selected[m] = default_set[m] or false end
        else
            local idx = tonumber(choice)
            if idx and idx >= 1 and idx <= #order then
                selected[order[idx]] = not selected[order[idx]]
            end
        end
    end
end

local function file_menu(mode)
    clear_screen()
    print_header('文件路径')
    local default_in = (mode == 'forward') and 'input.lua' or 'input.luac'
    local default_out = (mode == 'forward') and 'output.luac' or 'output.lua'
    local input = ask('输入文件 (默认 ' .. default_in .. '): ')
    if input == '' then input = default_in end
    local output = ask('输出文件 (默认 ' .. default_out .. '): ')
    if output == '' then output = default_out end
    return input, output
end

local function load_module(name, mode)
    local ok, mod = pcall(require, name)
    if not ok then return nil, tostring(mod) end
    return mod
end

local function get_fn(mod, mode)
    if mode == 'reverse' then
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

local function execute(mode, modules, input, output)
    clear_screen()
    print_header('执行中')
    print('模式: ' .. (mode == 'forward' and '混淆' or '去混淆'))
    print('输入: ' .. input)
    print('输出: ' .. output)
    print('模块: ' .. table.concat(modules, ', '))
    print('---')

    local fin = io.open(input, 'rb')
    if not fin then print('ERROR: 无法打开 ' .. input); return end
    local data = fin:read('*a')
    fin:close()

    local proto
    if mode == 'reverse' then
        proto = luac.undump(data, false)
    else
        proto = compile_source(data)
    end

    local total = 0
    for _, name in ipairs(modules) do
        local mod, err = load_module(name, mode)
        if not mod then
            print(string.format('  [SKIP] %s: %s', name, err))
        else
            local fn = get_fn(mod, mode)
            if not fn then
                print(string.format('  [SKIP] %s: 无入口函数', name))
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

    local out_bc = luac.dump(proto)
    local fout = io.open(output, 'wb')
    if not fout then print('ERROR: 无法写入 ' .. output); return end
    fout:write(out_bc)
    fout:close()

    print('---')
    print(string.format('输出: %s (%d bytes)', output, #out_bc))
    print(string.format('总计变更: %d', total))
    print()
    ask('按回车返回主菜单...')
end

local function main()
    while true do
        local mode = mode_menu()
        local modules = module_menu(mode)
        if #modules == 0 then
            print('未选择任何模块!')
            ask('按回车继续...')
        else
            local input, output = file_menu(mode)
            execute(mode, modules, input, output)
        end
    end
end

main()
