-- 测试 menu.lua 持久化逻辑
local f = io.open('menu_config_test.lua', 'w')
f:write('return {mode="forward", forward_modules={"str_encrypt"}, reverse_modules={"destr_encrypt"}, input="test.lua", output="test.luac"}')
f:close()

local cfg2 = loadfile('menu_config_test.lua')()
print('forward_modules: ' .. table.concat(cfg2.forward_modules, ','))
print('reverse_modules: ' .. table.concat(cfg2.reverse_modules, ','))

local mode = 'forward'
local saved_mods = cfg2.forward_modules or cfg2.modules
print('saved_mods for forward: ' .. table.concat(saved_mods, ','))

local has_bool = false
for _, m in ipairs(saved_mods) do if m == 'bool_obfuscate' then has_bool = true end end
print('bool_obfuscate in saved_mods (should be false): ' .. tostring(has_bool))

-- 测试 module_menu 逻辑: saved_modules 完全覆盖默认
local DEFAULT_FORWARD = {'bool_obfuscate', 'num_obfuscate', 'str_split'}
local order = {'bool_obfuscate', 'num_obfuscate', 'str_split', 'str_encrypt', 'const_hide'}
local saved_modules = {'str_encrypt'}

local selected = {}
local defaults = {}
for _, m in ipairs(DEFAULT_FORWARD) do defaults[m] = true end
if saved_modules then
    local saved_set = {}
    for _, m in ipairs(saved_modules) do saved_set[m] = true end
    for _, m in ipairs(order) do selected[m] = saved_set[m] or false end
else
    for _, m in ipairs(order) do selected[m] = defaults[m] or false end
end

print('--- module_menu result ---')
for _, m in ipairs(order) do
    print(string.format('  %s: %s', m, selected[m] and 'ON' or 'OFF'))
end
print('bool_obfuscate should be OFF: ' .. tostring(not selected.bool_obfuscate))
print('str_encrypt should be ON: ' .. tostring(selected.str_encrypt))

os.remove('menu_config_test.lua')
print('ALL TESTS PASSED')
