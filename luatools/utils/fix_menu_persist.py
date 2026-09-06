#!/usr/bin/env python3
"""Fix menu.lua module selection persistence:
1. Saved modules completely replace defaults (not OR)
2. Forward/reverse module lists saved separately
"""
path = r'E:\LuaRes\luatools\menu.lua'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

# 1. save_config: save forward/reverse modules separately
old_save = '''local function save_config(mode, modules, input, output)
    local f = io.open(CONFIG_FILE, 'w')
    if not f then return end
    f:write('return {\\n')
    f:write(string.format('  mode = %q,\\n', mode))
    f:write('  modules = {')
    for i, m in ipairs(modules) do
        if i > 1 then f:write(', ') end
        f:write(string.format('%q', m))
    end
    f:write('},\\n')
    f:write(string.format('  input = %q,\\n', input or ''))
    f:write(string.format('  output = %q,\\n', output or ''))
    f:write('}\\n')
    f:close()
end'''

new_save = '''local function save_config(mode, modules, input, output)
    local f = io.open(CONFIG_FILE, 'w')
    if not f then return end
    -- 读取旧配置以保留另一个模式的模块列表
    local old = load_config() or {}
    local fwd_mods = (mode == 'forward') and modules or (old.forward_modules or old.modules or {})
    local rev_mods = (mode == 'reverse') and modules or (old.reverse_modules or {})
    f:write('return {\\n')
    f:write(string.format('  mode = %q,\\n', mode))
    f:write('  forward_modules = {')
    for i, m in ipairs(fwd_mods) do
        if i > 1 then f:write(', ') end
        f:write(string.format('%q', m))
    end
    f:write('},\\n')
    f:write('  reverse_modules = {')
    for i, m in ipairs(rev_mods) do
        if i > 1 then f:write(', ') end
        f:write(string.format('%q', m))
    end
    f:write('},\\n')
    f:write(string.format('  input = %q,\\n', input or ''))
    f:write(string.format('  output = %q,\\n', output or ''))
    f:write('}\\n')
    f:close()
end'''

if old_save in src:
    src = src.replace(old_save, new_save, 1)
    print("save_config fixed")
else:
    print("FAILED: save_config not found")

# 2. module_menu: saved modules completely replace defaults
old_module = '''local function module_menu(mode, saved_modules)
    local order = (mode == 'forward') and FORWARD_ORDER or REVERSE_ORDER
    local selected = {}
    local default_set = {}
    if mode == 'forward' then
        for _, m in ipairs(DEFAULT_FORWARD) do default_set[m] = true end
    end
    if saved_modules then
        for _, m in ipairs(saved_modules) do default_set[m] = true end
    end
    for _, m in ipairs(order) do selected[m] = default_set[m] or false end'''

new_module = '''local function module_menu(mode, saved_modules)
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
    end'''

if old_module in src:
    src = src.replace(old_module, new_module, 1)
    print("module_menu fixed")
else:
    print("FAILED: module_menu not found")

# 3. 'd' handler: use defaults table (variable renamed)
old_d = '''        elseif choice == 'd' then
            for _, m in ipairs(order) do selected[m] = default_set[m] or false end'''
new_d = '''        elseif choice == 'd' then
            for _, m in ipairs(order) do selected[m] = defaults[m] or false end'''

if old_d in src:
    src = src.replace(old_d, new_d, 1)
    print("'d' handler fixed")
else:
    print("FAILED: 'd' handler not found")

# 4. main: load appropriate module list based on mode
old_main = '''        local saved_mods = (cfg and cfg.mode == mode) and cfg.modules or nil'''
new_main = '''        local saved_mods = nil
        if cfg then
            if mode == 'forward' then
                saved_mods = cfg.forward_modules or cfg.modules
            else
                saved_mods = cfg.reverse_modules
            end
        end'''

if old_main in src:
    src = src.replace(old_main, new_main, 1)
    print("main fixed")
else:
    print("FAILED: main not found")

with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
print("Done")
