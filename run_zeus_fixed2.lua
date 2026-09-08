-- Run fixed vm_embed zeus script in stub environment
-- (reuse the stub environment from test_zeus_stub.lua but load fixed output)

local stub_code = [[
local stub_calls = {}
local function record_call(name, ...)
    local args = {...}
    local argstr = {}
    for i = 1, select('#', ...) do
        local v = args[i]
        if type(v) == 'string' then table.insert(argstr, '"' .. v:sub(1, 40) .. '"')
        elseif type(v) == 'number' then table.insert(argstr, tostring(v))
        elseif type(v) == 'boolean' then table.insert(argstr, tostring(v))
        elseif type(v) == 'table' then table.insert(argstr, 'table')
        elseif v == nil then table.insert(argstr, 'nil')
        else table.insert(argstr, type(v)) end
    end
    table.insert(stub_calls, name .. '(' .. table.concat(argstr, ', ') .. ')')
end

local function make_stub_func(full_name)
    return function(...)
        record_call(full_name, ...)
        local lower = full_name:lower()
        if lower:find('get_') or lower:find('is_') or lower:find('has_') or lower:find('can_') then
            if lower:find('coords') or lower:find('position') then return {x=0,y=0,z=0} end
            if lower:find('id') then return 1 end
            if lower:find('bool') or lower:find('active') or lower:find('exist') or lower:find('visible') or lower:find('in_vehicle') then return false end
            if lower:find('int') or lower:find('level') or lower:find('health') or lower:find('armour') or lower:find('tick') or lower:find('count') or lower:find('size') or lower:find('heading') then return 0 end
            if lower:find('float') then return 0.0 end
            if lower:find('string') or lower:find('text') or lower:find('name') then return "" end
            if lower:find('table') or lower:find('list') then return {} end
            return nil
        elseif lower:find('read_file') then return nil end
        elseif lower:find('write_file') then return true end
        elseif lower:find('escape') then local a={...}; return tostring(a[1] or "") end
        elseif lower:find('post') or lower:find('curl') then return {body='{"token":"stub","expires":9999999999,"build_id":"stub","watermark":"stub"}',status=200} end
        elseif lower:find('calc_text_size') then return {w=100,h=20} end
        elseif lower:find('get_display_size') then return {w=1920,h=1080} end
        elseif lower:find('get_mouse_pos') then return {x=0,y=0} end
        elseif lower:find('get_input_characters') then return "" end
        elseif lower:find('is_mouse_clicked') or lower:find('is_key_pressed') or lower:find('is_mouse_down') then return false end
        elseif lower:find('joaat') then return 0 end
        return nil
    end
end

local function make_stub_table(prefix)
    local t = {}
    setmetatable(t, {__index = function(self, key)
        local full = prefix .. '.' .. key
        local stub = make_stub_func(full)
        rawset(self, key, stub)
        return stub
    end})
    return t
end

local env = {}
env._G = env; env._VERSION = "Lua 5.3"
env.print = print; env.type = type; env.tostring = tostring; env.tonumber = tonumber
env.pairs = pairs; env.ipairs = ipairs; env.next = next; env.select = select
env.unpack = table.unpack; env.error = error; env.pcall = pcall; env.xpcall = xpcall
env.assert = assert; env.setmetatable = setmetatable; env.getmetatable = getmetatable
env.rawget = rawget; env.rawset = rawset; env.rawequal = rawequal
env.string = string; env.table = table; env.math = math; env.os = os; env.io = io
env.coroutine = coroutine; env.debug = debug

for _, ns in ipairs({'filesystem','ui','util','menu','native','player','weapon','entity','ped','vehicle','gameplay','gta','system','network','camera','audio','object','world'}) do
    env[ns] = make_stub_table(ns)
end
env.ui.draw = make_stub_table('ui.draw')
env.ui.add = make_stub_table('ui.add')
env.util.curl = make_stub_table('util.curl')
env.util.data = make_stub_table('util.data')
env.util.loop = make_stub_table('util.loop')
env.util.notify = make_stub_table('util.notify')
env.MISC_MENU = 0

local f = assert(io.open("E:\\LuaRes\\zeus_vm_embed_fixed.lua", "r"))
local code = f:read("*a"); f:close()
local func, err = load(code, "zeus_fixed", "t", env)
if not func then print("LOAD ERROR: " .. tostring(err)); os.exit(1) end
local ok, run_err = pcall(func)
if not ok then print("RUNTIME ERROR: " .. tostring(run_err)) else print("=== Run completed successfully ===") end
print("=== Total stub calls: " .. #stub_calls .. " ===")
]]

local f = load(stub_code)
f()
