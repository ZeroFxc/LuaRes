-- table_obfuscate 正反向测试
package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"

local luac = require('luac')
local to = require('table_obfuscate')
local dto = require('detable_obfuscate')

math.randomseed(12345)

local TESTS = {
    {
        name = '基础表读写',
        src = [[
            local t = {a=1, b=2, c=3}
            t.d = 4
            t["e"] = 5
            return t.a + t.b + t.c + t.d + t.e
        ]],
        expect = 15,
    },
    {
        name = '数组与混合',
        src = [[
            local t = {10, 20, x=30, 40, y=50}
            return t[1] + t[2] + t[3] + t.x + t.y
        ]],
        expect = 150,
    },
    {
        name = '嵌套表',
        src = [[
            local t = {a={b={c=42}}}
            return t.a.b.c
        ]],
        expect = 42,
    },
    {
        name = '方法调用',
        src = [[
            local t = {val=100}
            function t:add(n) return self.val + n end
            return t:add(50)
        ]],
        expect = 150,
    },
    {
        name = '大数组',
        src = [[
            local t = {}
            for i=1,100 do t[i] = i end
            local s = 0
            for i=1,100 do s = s + t[i] end
            return s
        ]],
        expect = 5050,
    },
    {
        name = 'upvalue表',
        src = [[
            local t = {count=0}
            local function inc() t.count = t.count + 1 end
            inc(); inc(); inc()
            return t.count
        ]],
        expect = 3,
    },
    {
        name = '表中函数',
        src = [[
            local t = {add=function(a,b) return a+b end}
            return t.add(3,4)
        ]],
        expect = 7,
    },
    {
        name = '元表',
        src = [[
            local t = setmetatable({}, {__index=function() return 99 end})
            return t.nonexistent
        ]],
        expect = 99,
    },
    {
        name = '复杂表操作',
        src = [[
            local t = {items={}, meta={version=1}}
            table.insert(t.items, {id=1, name="a"})
            table.insert(t.items, {id=2, name="b"})
            t.meta.count = #t.items
            return t.meta.version + t.meta.count + t.items[1].id + t.items[2].id
        ]],
        expect = 1+2+1+2,
    },
}

local function compile(src)
    local func = load(src)
    local shell = string.dump(func)
    local bc = string.dec(shell)
    return luac.undump(bc, false)
end

local function run_proto(proto)
    local bc = luac.dump(proto)
    local func = load(bc)
    return func()
end

local total_pass = 0
local total_fail = 0

for _, test in ipairs(TESTS) do
    io.write(string.format('[%s] ', test.name))
    local proto = compile(test.src)
    local orig_code_count = #proto.code

    -- 正向混淆
    local changes = to.obfuscate(proto, {
        newtable_rate = 1.0,
        self_rate = 1.0,
        gettable_key_rate = 1.0,
        settable_key_rate = 1.0,
        settable_val_rate = 1.0,
        gettabup_key_rate = 1.0,
        settabup_rate = 1.0,
    })
    local obf_code_count = #proto.code

    -- 验证混淆后可执行
    local ok, result = pcall(run_proto, proto)
    if not ok then
        print(string.format('FAIL: 混淆后执行错误: %s', tostring(result)))
        total_fail = total_fail + 1
        goto continue
    end
    if result ~= test.expect then
        print(string.format('FAIL: 混淆后结果=%s, 期望=%s', tostring(result), tostring(test.expect)))
        total_fail = total_fail + 1
        goto continue
    end

    -- 反向还原
    local restored = dto.clean(proto)
    local deobf_code_count = #proto.code

    -- 验证还原后可执行
    local ok2, result2 = pcall(run_proto, proto)
    if not ok2 then
        print(string.format('FAIL: 还原后执行错误: %s', tostring(result2)))
        total_fail = total_fail + 1
        goto continue
    end
    if result2 ~= test.expect then
        print(string.format('FAIL: 还原后结果=%s, 期望=%s', tostring(result2), tostring(test.expect)))
        total_fail = total_fail + 1
        goto continue
    end

    print(string.format('PASS | 指令 %d -> %d -> %d | 混淆变更=%d 还原=%d',
        orig_code_count, obf_code_count, deobf_code_count, changes, restored))
    total_pass = total_pass + 1

    ::continue::
end

print(string.format('\n=== 结果: %d 通过, %d 失败 ===', total_pass, total_fail))
os.exit(total_fail > 0 and 1 or 0)
