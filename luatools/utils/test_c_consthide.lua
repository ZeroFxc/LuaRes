-- test const_hide C module forward+reverse
local luac = require('luac')

local cases = {
    {name="two_strings", src='local a="hello" local b="world" return a..b', expect="helloworld"},
    {name="table_key", src='local t={["key1"]=1, ["key2"]=2} return t.key1 + t.key2', expect=3},
    {name="method", src='local t={} function t:foo() return "x" end return t:foo()', expect="x"},
    {name="global", src='gvar = "hello" return gvar', expect="hello"},
    {name="settable", src='local t={} t["k"]="v" return t.k', expect="v"},
    {name="long", src='local a="this is a very long string for testing" return a', expect="this is a very long string for testing"},
    {name="concat3", src='local a="foo" local b="bar" local c="baz" return a..b..c', expect="foobarbaz"},
}

local pass, fail = 0, 0
for _, tc in ipairs(cases) do
    local func = load(tc.src)
    local bc = string.dec(string.dump(func))
    local proto = luac.undump(bc, false)
    local fwd = luac.const_hide_c(proto)
    local enc = luac.dump(proto)
    local ok1, result1 = pcall(load(enc))
    local r1 = ok1 and result1 or nil

    local proto2 = luac.undump(enc, false)
    local rev = luac.deconst_hide_c(proto2)
    local dec = luac.dump(proto2)
    local ok2, result2 = pcall(load(dec))
    local r2 = ok2 and result2 or nil

    if r1 == tc.expect and r2 == tc.expect then
        print(string.format("PASS %-14s fwd=%d rev=%d result=%s", tc.name, fwd, rev, tostring(r1)))
        pass = pass + 1
    else
        print(string.format("FAIL %-14s fwd=%s rev=%s got=%s/%s expect=%s", tc.name,
            tostring(fwd), tostring(rev), tostring(r1), tostring(r2), tostring(tc.expect)))
        fail = fail + 1
    end
end
print(string.format("=== %d pass, %d fail ===", pass, fail))
