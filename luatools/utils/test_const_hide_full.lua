package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local ch = require('const_hide')
local dch = require('deconst_hide')

local TESTS = {
    {name='基础', src='local a="hello" local b="world" return a..b', expect='helloworld'},
    {name='表键', src='local t={v=10} return t.v', expect=10},
    {name='全局', src='x=42 return x', expect=42},
    {name='全局写', src='x=42 x=x+1 return x', expect=43},
    {name='方法', src='local t={v=10} function t:f(n) return self.v+n end return t:f(5)', expect=15},
    {name='多串', src='local a="aa" local b="bb" local c="cc" return a..b..c', expect='aabbcc'},
    {name='空串', src='local a="" local b="x" return #a..#b', expect='01'},
    {name='长串', src='local s=string.rep("abc",100) return #s', expect=300},
    {name='数字混合', src='local a="test" local b=42 return a..b', expect='test42'},
    {name='upvalue', src='local t={c=0} local function inc() t.c=t.c+1 end inc() inc() return t.c', expect=2},
    {name='表多键', src='local t={a=1,b=2,c=3} return t.a+t.b+t.c', expect=6},
}

local pass, fail = 0, 0
for _, test in ipairs(TESTS) do
    local proto = luac.undump(string.dec(string.dump(load(test.src))), false)

    -- 正向
    ch.process(proto)
    local ok_fwd, r_fwd = pcall(function() return load(luac.dump(proto))() end)

    -- 反向
    dch.clean(proto)
    local ok_rev, r_rev = pcall(function() return load(luac.dump(proto))() end)

    -- 检查反向后常量池是否还原(没有blob了)
    local has_blob = false
    for i = 1, #proto.k do
        if type(proto.k[i]) == 'string' and #proto.k[i] > 40 then has_blob = true end
    end

    local fwd_ok = ok_fwd and r_fwd == test.expect
    local rev_ok = ok_rev and r_rev == test.expect
    local ok = fwd_ok and rev_ok

    if ok then pass = pass + 1 else fail = fail + 1 end
    print(string.format('%-10s fwd=%s(%s) rev=%s(%s) has_blob=%s %s',
        test.name, tostring(ok_fwd), tostring(r_fwd),
        tostring(ok_rev), tostring(r_rev), tostring(has_blob),
        ok and 'PASS' or 'FAIL'))
end
print(string.format('=== %d pass, %d fail ===', pass, fail))
