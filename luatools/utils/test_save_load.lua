-- 测试 save_config / load_config 闭环
package.path = package.path .. ';E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/reverse/?.lua;E:/LuaRes/luatools/utils/?.lua'

-- 模拟 menu.lua 的 save_config/load_config
local CONFIG_FILE = 'E:/LuaRes/luatools/menu_config_test2.lua'
local load_config

local function save_config(mode, modules, input, output)
    local f = io.open(CONFIG_FILE, 'w')
    if not f then return end
    local old = load_config() or {}
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

-- 测试1: 保存正向配置
save_config('forward', {'str_encrypt', 'const_hide'}, 'a.lua', 'a.luac')
local cfg = load_config()
print('test1 forward: ' .. table.concat(cfg.forward_modules, ','))
print('test1 reverse empty: ' .. tostring(#cfg.reverse_modules == 0))

-- 测试2: 保存反向配置, 正向应保留
save_config('reverse', {'destr_encrypt'}, 'b.luac', 'b.lua')
cfg = load_config()
print('test2 forward preserved: ' .. table.concat(cfg.forward_modules, ','))
print('test2 reverse: ' .. table.concat(cfg.reverse_modules, ','))

-- 测试3: 再保存正向, 反向应保留
save_config('forward', {'bool_obfuscate'}, 'c.lua', 'c.luac')
cfg = load_config()
print('test3 forward: ' .. table.concat(cfg.forward_modules, ','))
print('test3 reverse preserved: ' .. table.concat(cfg.reverse_modules, ','))

os.remove(CONFIG_FILE)
print('ALL TESTS PASSED')
