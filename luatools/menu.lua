-- luatools/menu.lua - 交互式菜单版字节码混淆/去混淆工具
-- 用法: lua_luac2.exe menu.lua

os.execute("chcp 65001 >nul 2>nul")

package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"

local luac = require('luac')
local fix_maxstack = require('fix_maxstack')

local FORWARD_ORDER = {
    'const_hide', 'const_shuffle', 'str_encrypt', 'instruction_mutate', 'num_obfuscate', 'str_split', 'bool_obfuscate',
    'table_obfuscate', 'opaque_predicate',
    'const_poison', 'opaque_junk', 'junk_jmp', 'junk_loadk',
    'junk_move', 'op48_junk',
    'luac_obfuscate', 'luac_flatten', 'debug_strip',
    'antidec', 'proto_shuffle', 'live_range_split',
}

local FORWARD_DESC = {
    bool_obfuscate = '布尔值混淆',
    num_obfuscate = '数字运算混淆',
    str_split = '字符串分割混淆',
    str_encrypt = '字符串加密(运行时解密)',
    const_hide = '常量池隐藏(字符串合并blob)',
    const_shuffle = '常量池乱序',
    instruction_mutate = '指令等价替换',
    table_obfuscate = '表指令混淆',
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
    proto_shuffle = '子函数Proto重排',
    live_range_split = '寄存器活跃范围分裂',
}

local REVERSE_ORDER = {
    'fix_antidec', 'deop48', 'dejunk_jmp', 'dejunk_loadk',
    'dejunk_move', 'deopaque_junk', 'deconst_poison',
    'deopaque_predicate', 'deinstruction_mutate', 'detable_obfuscate',
    'deconst_shuffle', 'denum_obfuscate', 'debool_obfuscate',
    'destr_split', 'destr_encrypt', 'deconst_hide',
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
    detable_obfuscate = '还原表指令混淆',
    deconst_shuffle = '还原常量池乱序',
    denum_obfuscate = '还原数字混淆',
    debool_obfuscate = '还原布尔值混淆',
    destr_split = '还原字符串分割',
    destr_encrypt = '还原字符串加密',
    deconst_hide = '还原常量池隐藏',
    deflatten = '还原控制流扁平化',
    dedebug_strip = '恢复调试信息(不可行)',
    deprotect = '综合去保护',
    de_junk_obfuscate = '综合垃圾指令去除',
}

local DEFAULT_FORWARD = {}  -- 无默认勾选模块

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
local load_config  -- 前向声明, save_config 需要调用

local function save_config(mode, modules, input, output)
    -- 先读旧配置(必须在打开写之前, 否则'w'模式会截断文件)
    local old = load_config() or {}
    local f = io.open(CONFIG_FILE, 'w')
    if not f then return end
    local fwd_mods = (mode == 'forward') and modules or (old.forward_modules or old.modules or {})
    local rev_mods = (mode == 'reverse') and modules or (old.reverse_modules or {})
    f:write('return {\n')
    f:write(string.format('  mode = %q,\n', mode))
    f:write('  forward_modules = {')
    for i, m in ipairs(fwd_mods) do
        if i > 1 then f:write(', ') end
        f:write(string.format('%q', m))
    end
    f:write('},\n')
    f:write('  reverse_modules = {')
    for i, m in ipairs(rev_mods) do
        if i > 1 then f:write(', ') end
        f:write(string.format('%q', m))
    end
    f:write('},\n')
    f:write(string.format('  input = %q,\n', input or ''))
    f:write(string.format('  output = %q,\n', output or ''))
    f:write('}\n')
    f:close()
end

load_config = function()
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
    -- 默认集合 (仅用于 'd' 恢复默认)
    local defaults = {}
    if mode == 'forward' then
        for _, m in ipairs(DEFAULT_FORWARD) do defaults[m] = true end
    end
    if saved_modules then
        -- 有保存的配置, 完全以保存的为准 (不与默认OR)
        local saved_set = {}
        for _, m in ipairs(saved_modules) do saved_set[m] = true end
        for _, m in ipairs(order) do selected[m] = saved_set[m] or false end
    else
        for _, m in ipairs(order) do selected[m] = defaults[m] or false end
    end

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
            for _, m in ipairs(order) do selected[m] = defaults[m] or false end
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

-- 正向模块真实入口函数映射
local FORWARD_FN = {
    bool_obfuscate = 'obfuscate',
    num_obfuscate = 'obfuscate',
    str_split = 'obfuscate',
    str_encrypt = 'encrypt',
    const_hide = 'process',
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
    proto_shuffle = 'shuffle',
    live_range_split = 'split',
}

-- 反向模块真实入口函数映射
local REVERSE_FN = {
    deop48 = 'clean',
    dejunk_jmp = 'clean',
    dejunk_loadk = 'clean',
    dejunk_move = 'clean',
    deopaque_junk = 'clean',
    deopaque_predicate = 'clean',
    deconst_shuffle = 'clean',
    deinstruction_mutate = 'clean',
    detable_obfuscate = 'clean',
    debool_obfuscate = 'clean',
    denum_obfuscate = 'clean',
    destr_split = 'clean',
    destr_encrypt = 'clean',
    deconst_hide = 'clean',
    deconst_poison = 'clean',
    deflatten = 'clean',
    dedebug_strip = 'clean',
    fix_antidec = 'clean',
    deprotect = 'clean',
    de_junk_obfuscate = 'clean',
    deobfuscate = 'run',
}

local function get_fn(name, mode)
    local map = (mode == 'reverse') and REVERSE_FN or FORWARD_FN
    local fn_name = map[name]
    if not fn_name then return nil end
    local mod = package.loaded[name]
    if not mod then return nil end
    return mod[fn_name]
end

local function read_file(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local data = f:read('*a')
    f:close()
    return data
end

local function compile_source(data)
    local first = data:byte(1)

    -- 字节码直接 undump，绝不经过 load->string.dump->string.dec。
    -- string.dec 内部 inflate 输出缓冲固定为 inlen*8+4096，
    -- 超容时不检查 Z_STREAM_END 就返回截断数据，导致 proto 缩水。
    -- 0x1B=标准字节码  0x1C/0x1A=andlua 加密字节码（luac.undump 自带识别）
    if first == 0x1B or first == 0x1C or first == 0x1A then
        return luac.undump(data, false)
    end

    -- andlua '=' base64 加密壳：dec 还原成 0x1A 字节码后 undump
    if first == 0x3D then  -- '='
        return luac.undump(string.dec(data), false)
    end

    -- Lua 源码：load 编译 -> dump 成 andlua 壳 -> dec 还原 -> undump
    local func, err = load(data)
    if func then
        return luac.undump(string.dec(string.dump(func)), false)
    end

    -- 兜底：当作文件路径读取（支持中文路径）
    local content = read_file(data)
    if content then
        return compile_source(content)
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

    local data = read_file(input)
    if not data then print('ERROR: 无法打开 ' .. input); return end

    local proto = compile_source(data)

    local total = 0
    for _, name in ipairs(modules) do
        local mod, err = load_module(name, mode)
        if not mod then
            print(string.format('  [SKIP] %s: %s', name, err))
        else
            local fn = get_fn(name, mode)
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

    -- 正向混淆后修正 maxstacksize: 多模块叠加时各模块独立管理临时寄存器,
    -- 可能出现指令引用了高寄存器但 maxstacksize 未同步的情况
    if mode == 'forward' then
        fix_maxstack.fix(proto)
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
        local saved_mods = nil
        if cfg then
            if mode == 'forward' then
                saved_mods = cfg.forward_modules or cfg.modules
            else
                saved_mods = cfg.reverse_modules
            end
        end
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
