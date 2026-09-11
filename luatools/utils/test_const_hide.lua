package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local ch = require('const_hide')

local TESTS = {
    {name='基础', src='local a="hello" local b="world" return a..b', expect='helloworld'},
    {name='表键', src='local t={v=10} return t.v', expect=10},
    {name='全局', src='x=42 return x', expect=42},
    {name='方法', src='local t={v=10} function t:f(n) return self.v+n end return t:f(5)', expect=15},
    {name='多串', src='local a="aa" local b="bb" local c="cc" return a..b..c', expect='aabbcc'},
    {name='空串', src='local a="" local b="x" return #a..#b', expect='01'},
}

for _, test in ipairs(TESTS) do
    local proto = luac.undump(string.dec(string.dump(load(test.src))), false)
    local n = ch.process(proto)

    -- 检查常量池字符串数量
    local str_count = 0
    for i = 1, #proto.k do
        if type(proto.k[i]) == 'string' then str_count = str_count + 1 end
    end

    local ok, r = pcall(function() return load(luac.dump(proto))() end)
    local pass = ok and r == test.expect
    print(string.format('%-8s count=%d str_in_k=%d ok=%s result=%s expect=%s %s',
        test.name, n, str_count, tostring(ok), tostring(r), tostring(test.expect),
        pass and 'PASS' or 'FAIL'))
end
