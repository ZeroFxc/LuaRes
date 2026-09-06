package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local se = require('str_encrypt')
local de = require('destr_encrypt')

local TESTS = {
    {name='基础', src='local a="hello" local b="world" return a..b', expect='helloworld'},
    {name='表键', src='local t={v=10} return t.v', expect=10},
    {name='方法', src='local t={v=10} function t:f(n) return self.v+n end return t:f(5)', expect=15},
    {name='upvalue', src='local t={c=0} local function inc() t.c=t.c+1 end inc() inc() return t.c', expect=2},
    {name='空串', src='local a="" local b="x" return #a..#b', expect='01'},
    {name='长串', src='local s=string.rep("abc",100) return #s', expect=300},
    {name='数字混合', src='local a="test" local b=42 return a..b', expect='test42'},
}

local pass, fail = 0, 0
for _, test in ipairs(TESTS) do
    math.randomseed(12345)
    local proto = luac.undump(string.dec(string.dump(load(test.src))), false)
    local orig_k = {}
    for i = 1, #proto.k do orig_k[i] = proto.k[i] end

    -- 正向
    se.encrypt(proto, {})
    local ok_fwd, result_fwd = pcall(function() return load(luac.dump(proto))() end)

    -- 反向
    de.clean(proto)
    local ok_rev, result_rev = pcall(function() return load(luac.dump(proto))() end)

    local fwd_ok = ok_fwd and result_fwd == test.expect
    local rev_ok = ok_rev and result_rev == test.expect

    -- 检查常量是否还原
    local k_restored = true
    for i = 1, #orig_k do
        if proto.k[i] ~= orig_k[i] then k_restored = false; break end
    end

    if fwd_ok and rev_ok and k_restored then
        pass = pass + 1
        print(string.format('PASS %-10s fwd=%s rev=%s k_restored=%s', test.name, tostring(result_fwd), tostring(result_rev), tostring(k_restored)))
    else
        fail = fail + 1
        print(string.format('FAIL %-10s fwd_ok=%s(%s) rev_ok=%s(%s) k_restored=%s',
            test.name, tostring(ok_fwd), tostring(result_fwd),
            tostring(ok_rev), tostring(result_rev), tostring(k_restored)))
    end
end
print(string.format('=== %d pass, %d fail ===', pass, fail))
