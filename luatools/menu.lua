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

local FORWARD_DESC = {
    bool_obfuscate = '布尔值混淆',
    num_obfuscate = '数字运算混淆',
    str_split = '字符串分割混淆',
    str_encrypt = '字符串加密(运行时解密)',
    const_shuffle = '常量池乱序',
    instruction_mutate = '指令等价替换',
    opaque_predicate = '不透明谓词死分支',
    const_poison = '常量池投毒',
    opaque_junk = '不透明谓词垃圾指令',
    junk_jmp = '垃圾跳转指令',
    junk_loadk = '垃圾LOADK指令',
    junk_move = '垃圾MOVE指令',
    op48_junk = 'OP48无效操作码垃圾',
    luac_obfuscate = '控制流混淆',
    luac_flatten = '控制流扁平化',
    debug_strip = '调试信息剥离',
    antidec = '反编译防护',
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

local REVERSE_DESC = {
    fix_antidec = '修复反编译防护',
    deop48 = '去除OP48垃圾指令',
    dejunk_jmp = '去除垃圾跳转',
    dejunk_loadk = '去除垃圾LOADK',
    dejunk_move = '去除垃圾MOVE',
    deopaque_junk = '去除不透明谓词垃圾',
    deconst_poison = '去除常量池投毒',
    deopaque_predicate = '去除不透明谓词死分支',
    deinstruction_mutate = '还原指令等价替换',
    deconst_shuffle = '还原常量池乱序',
    denum_obfuscate = '还原数字混淆',
    debool_obfuscate = '还原布尔值混淆',
    destr_split = '还原字符串分割',
    destr_encrypt = '还原字符串加密',
    deflatten = '还原控制流扁平化',
    dedebug_strip = '恢复调试信息(不可行)',
    deprotect = '综合去保护',
    de_junk_obfuscate = '综合垃圾指令去除',
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
    local ok, result = pcall(io.read, '*l')
    if not ok then
        -- Ctrl+C 或其他中断
        print()
        os.exit(0)
    end
    return result
end

local CONFIG_FILE = 'E:/LuaRes/luatools/menu_config.lua'

local function save_config(mode, modules, input, output)
    local f = io.open(CONFIG_FILE, 'w')
    if not f then return end
    f:write('return {\n')
    f:write(string.format('  mode = %q,\n', mode))
    f:write('  modules = {')
    for i, m in ipairs(modules) do
        if i > 1 then f:write(', ') end
        f:write(string.format('%q', m))
    end
    f:write('},\n')
    f:write(string.format('  input = %q,\n', input or ''))
    f:write(string.format('  output = %q,\n', output or ''))
    f:write('}\n')
    f:close()
end

local function load_config()
    local f = io.open(CONFIG_FILE, 'r')
    if not f then return nil end
    local content = f:read('*a')
    f:close()
    local ok, cfg = pcall(load(content))
    if ok and type(cfg) == 'table' then return cfg end
    return nil
end

local function mode_menu(default_mode)
    clear_screen()
    print_header('选择模式')
    print('  [1] 混淆 (正向)')
    print('  [2] 去混淆 (反向)')
    print('  [0] 退出')
    if default_mode then
        print('  (上次: ' .. (default_mode == 'forward' and '混淆' or '去混淆') .. ')')
    end
    print()
    local choice = ask('请选择 (回车用上次): ')
    if choice == '' and default_mode then return default_mode end
    if choice == '1' then return 'forward'
    elseif choice == '2' then return 'reverse'
    elseif choice == '0' then os.exit(0)
    else return mode_menu(default_mode) end
end

local function module_menu(mode, saved_modules)
    local order = (mode == 'forward') and FORWARD_ORDER or REVERSE_ORDER
    local selected = {}
    local default_set = {}
    if mode == 'forward' then
        for _, m in ipairs(DEFAULT_FORWARD) do default_set[m] = true end
    end
    if saved_modules then
        for _, m in ipairs(saved_modules) do default_set[m] = true end
    end
    for _, m in ipairs(order) do selected[m] = default_set[m] or false end

    while true do
        clear_screen()
        print_header((mode == 'forward') and '选择混淆模块' or '选择去混淆模块')
        for i, m in ipairs(order) do
            local mark = selected[m] and '[x]' or '[ ]'
            local desc = (mode == 'forward') and FORWARD_DESC[m] or REVERSE_DESC[m]
            print(string.format('  %2d. %s %-22s %s', i, mark, m, desc or ''))
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

local function file_menu(mode, default_input, default_output)
    clear_screen()
    print_header('文件路径')
    local def_in = default_input or ((mode == 'forward') and 'input.lua' or 'input.luac')
    local def_out = default_output or ((mode == 'forward') and 'output.luac' or 'output.lua')
    local input = ask('输入文件 (默认 ' .. def_in .. '): ')
    if input == '' then input = def_in end
    input = input:gsub('^["\']', ''):gsub('["\']$', '')
    local output = ask('输出文件 (回车自动生成): ')
    if output == '' then
        output = input .. '.luac'
    end
    output = output:gsub('^["\']', ''):gsub('["\']$', '')
    return input, output
end

local function load_module(name, mode)
    local ok, mod = pcall(require, name)
    if not ok then return nil, tostring(mod) end
    return mod
end

local function get_fn(mod, mode)
    if mode == 'reverse' then
        return mod.clean or mod.deobfuscate or mod.run or mod.strip or mod.process
    else
        return mod.encrypt or mod.obfuscate or mod.run or mod.protect
            or mod.shuffle or mod.process or mod.inject or mod.strip
    end
end

local function compile_source(data)
    -- 尝试1: 作为Lua源码加载
    local func, err = load(data)
    if func then
        local bc = string.dec(string.dump(func))
        return luac.undump(bc, false)
    end
    -- 尝试2: 作为andlua加密字节码(string.dec解密壳)
    local ok, dec = pcall(string.dec, data)
    if ok and dec and #dec > 0 then
        local ok2, proto = pcall(luac.undump, dec, false)
        if ok2 and proto then return proto end
    end
    -- 尝试3: 作为未加密字节码直接加载
    local ok3, proto2 = pcall(luac.undump, data, false)
    if ok3 and proto2 then return proto2 end
    -- 尝试4: 作为源码文件路径读取
    local fin = io.open(data, 'rb')
    if fin then
        local src = fin:read('*a')
        fin:close()
        return compile_source(src)
    end
    error('无法解析输入: 不是有效的Lua源码、字节码或文件路径')
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

    local proto = compile_source(data)

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
    save_config(mode, modules, input, output)
    ask('按回车返回主菜单...')
end

local function main()
    local cfg = load_config()
    while true do
        local mode = mode_menu(cfg and cfg.mode)
        local saved_mods = (cfg and cfg.mode == mode) and cfg.modules or nil
        local modules = module_menu(mode, saved_mods)
        if #modules == 0 then
            print('未选择任何模块!')
            ask('按回车继续...')
        else
            local input, output = file_menu(mode, cfg and cfg.input, cfg and cfg.output)
            execute(mode, modules, input, output)
            cfg = load_config()  -- 刷新配置
        end
    end
end

main()
