-- Zeus script test harness with auto-stubbing
-- Creates stub implementations for all GTA5/YARI APIs

local stub_calls = {}
local function record_call(name, ...)
    local args = {...}
    local argstr = {}
    for i = 1, select('#', ...) do
        local v = args[i]
        if type(v) == 'string' then
            table.insert(argstr, '"' .. v:sub(1, 40) .. '"')
        elseif type(v) == 'number' then
            table.insert(argstr, tostring(v))
        elseif type(v) == 'boolean' then
            table.insert(argstr, tostring(v))
        elseif type(v) == 'table' then
            table.insert(argstr, 'table')
        elseif v == nil then
            table.insert(argstr, 'nil')
        else
            table.insert(argstr, type(v))
        end
    end
    local call = name .. '(' .. table.concat(argstr, ', ') .. ')'
    table.insert(stub_calls, call)
    if #stub_calls <= 100 then
        print('[STUB] ' .. call)
    end
end

-- Create a stub function that returns sensible defaults
local function make_stub_func(full_name)
    return function(...)
        record_call(full_name, ...)
        -- Return sensible defaults based on function name
        local lower = full_name:lower()
        if lower:find('get_') or lower:find('is_') or lower:find('has_') or lower:find('can_') then
            if lower:find('coords') or lower:find('position') or lower:find('pos') then
                return {x = 0.0, y = 0.0, z = 0.0}
            elseif lower:find('id') then
                return 1
            elseif lower:find('bool') or lower:find('active') or lower:find('exist') or lower:find('visible') or lower:find('in_vehicle') then
                return false
            elseif lower:find('int') or lower:find('level') or lower:find('health') or lower:find('armour') or lower:find('tick') or lower:find('count') or lower:find('size') or lower:find('heading') then
                return 0
            elseif lower:find('float') then
                return 0.0
            elseif lower:find('string') or lower:find('text') or lower:find('name') then
                return ""
            elseif lower:find('table') or lower:find('list') or lower:find('array') then
                return {}
            else
                return nil
            end
        elseif lower:find('read_file') then
            return nil  -- file not found
        elseif lower:find('write_file') then
            return true
        elseif lower:find('escape') then
            local args = {...}
            return tostring(args[1] or "")
        elseif lower:find('post') or lower:find('request') or lower:find('curl') then
            return {body = '{"token":"stub","expires":9999999999,"build_id":"stub","watermark":"stub"}', status = 200}
        elseif lower:find('calc_text_size') then
            return {w = 100, h = 20}
        elseif lower:find('get_display_size') then
            return {w = 1920, h = 1080}
        elseif lower:find('get_mouse_pos') then
            return {x = 0, y = 0}
        elseif lower:find('get_input_characters') then
            return ""
        elseif lower:find('is_mouse_clicked') or lower:find('is_key_pressed') or lower:find('is_mouse_down') then
            return false
        elseif lower:find('joaat') then
            return 0
        elseif lower:find('ipairs') or lower:find('pairs') then
            return ipairs({})
        end
        return nil
    end
end

-- Create a stub table with auto-generation via metatable
local function make_stub_table(prefix)
    local t = {}
    setmetatable(t, {
        __index = function(self, key)
            local full_name = prefix .. '.' .. key
            -- Check if it should be a nested table or function
            -- Heuristic: if key starts with uppercase or is a known namespace, return a table
            local stub = make_stub_func(full_name)
            rawset(self, key, stub)
            return stub
        end
    })
    return t
end

-- Build the global environment
local env = {}
env._G = env
env._VERSION = "Lua 5.3"
env.print = print
env.type = type
env.tostring = tostring
env.tonumber = tonumber
env.pairs = pairs
env.ipairs = ipairs
env.next = next
env.select = select
env.unpack = table.unpack
env.error = error
env.pcall = pcall
env.xpcall = xpcall
env.assert = assert
env.setmetatable = setmetatable
env.getmetatable = getmetatable
env.rawget = rawget
env.rawset = rawset
env.rawequal = rawequal
env.string = string
env.table = table
env.math = math
env.os = os
env.io = io
env.coroutine = coroutine
env.debug = debug

-- Auto-stub all known GTA5/YARI namespaces
local namespaces = {
    'filesystem', 'ui', 'util', 'menu', 'native', 'player',
    'weapon', 'entity', 'ped', 'vehicle', 'gameplay', 'gta',
    'system', 'network', 'camera', 'audio', 'object', 'world',
    'timecycle', 'fire', 'explosion', 'pathfind', 'mobilphone',
    'decisionmaker', 'task', 'ambient', 'cutscene', 'dataview',
    'files', 'script', 'stats', 'zone', 'waypoint', 'blip',
    'map', 'hud', 'minimap', 'notification', 'loading',
    'save', 'settings', 'input', 'control', 'keyboard', 'mouse',
    'pad', 'game', 'session', 'crew', 'social', 'store',
    'dlc', 'tunable', 'global', 'local', 'memory', 'pointer',
    'handle', 'pool', 'streaming', 'model', 'anim', 'clip',
    'expression', 'facial', 'movement', 'behaviour', 'combat',
    'perception', 'reaction', 'speech', 'voice', 'conversation',
    'relationship', 'group', 'team', 'faction', 'gang',
    'wanted', 'police', 'crime', 'law', 'judge', 'jury',
    'court', 'prison', 'jail', 'arrest', 'cuff', 'fine',
    'ticket', 'warrant', 'bounty', 'hit', 'contract', 'mission',
    'heist', 'robbery', 'burglary', 'theft', 'fraud', 'hacking',
    'drugs', 'weapons', 'ammo', 'explosives', 'melee', 'firearm',
    'vehicle_weapon', 'aircraft', 'helicopter', 'plane', 'boat',
    'submarine', 'bicycle', 'motorcycle', 'car', 'truck', 'bus',
    'train', 'tank', 'apc', 'jet', 'drone', 'rc',
}

for _, ns in ipairs(namespaces) do
    env[ns] = make_stub_table(ns)
end

-- Special: ui.draw needs to be a table (nested namespace)
env.ui.draw = make_stub_table('ui.draw')
env.ui.add = make_stub_table('ui.add')
env.util.curl = make_stub_table('util.curl')
env.util.data = make_stub_table('util.data')
env.util.loop = make_stub_table('util.loop')
env.util.notify = make_stub_table('util.notify')
env.native = make_stub_table('native')
env.player = make_stub_table('player')
env.weapon = make_stub_table('weapon')
env.menu = make_stub_table('menu')
env.filesystem = make_stub_table('filesystem')

-- MISC_MENU constant
env.MISC_MENU = 0

-- Load and run the vm_embed output
print("=== Loading vm_embed output ===")
local f = assert(io.open("E:\\LuaRes\\zeus_vm_embed.lua", "r"))
local code = f:read("*a")
f:close()

print("Code size: " .. #code .. " bytes")

local func, err = load(code, "zeus_vm_embed", "t", env)
if not func then
    print("LOAD ERROR: " .. tostring(err))
    os.exit(1)
end

print("=== Running ===")
local ok, run_err = pcall(func)
if not ok then
    print("RUNTIME ERROR: " .. tostring(run_err))
else
    print("=== Run completed successfully ===")
end

print("=== Total stub calls: " .. #stub_calls .. " ===")
if #stub_calls > 100 then
    print("... (first 100 shown above)")
end
