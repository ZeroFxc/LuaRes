package.path = package.path .. ';E:/LuaRes/luatools/forward/?.lua'
local luac = require('luac')

local f=io.open('C:/Users/ruilo/Downloads/tk.lua','rb')
local data=f:read('*a'); f:close()
print('orig:', #data)

local proto = luac.undump(data, false)
print('undump: main sc='..proto.sizecode..' sk='..#proto.k..' sp='..#proto.p)

-- menu.lua 的模块顺序（用户勾选的）
local modules = {
    {'bool_obfuscate', 'obfuscate'},
    {'num_obfuscate', 'obfuscate'},
    {'str_split', 'obfuscate'},
    {'const_shuffle', 'shuffle'},
    {'opaque_predicate', 'process_function'},
    {'op48_junk', 'inject'},
    {'debug_strip', 'strip'},
    {'antidec', 'protect'},
}

for _, entry in ipairs(modules) do
    local name, fn_name = entry[1], entry[2]
    local mod = require(name)
    local fn = mod[fn_name]
    if not fn then
        print(string.format('%-20s NO_FUNC %s', name, fn_name))
    else
        local ok, n = pcall(fn, proto, {})
        if not ok then
            print(string.format('%-20s FAIL: %s', name, tostring(n):sub(1,80)))
        else
            n = tonumber(n) or 0
            -- 立即 dump 看大小
            local out = luac.dump(proto)
            local func, lerr = load(out)
            print(string.format('%-20s changes=%-6d dump=%-8d sk=%-4d sp=%-4d load=%s',
                name, n, #out, #proto.k, #proto.p, func and 'OK' or ('FAIL:'..tostring(lerr):sub(1,30))))
        end
    end
end
print('done')
