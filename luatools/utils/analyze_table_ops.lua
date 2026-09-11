-- 表操作字节码分析：编译各种表变式并反汇编 opcode
local luac = require('luac')

local BITRK = 0x100

local function fmt_operand(v, proto)
    if v >= BITRK then
        local idx = v - BITRK
        local k = proto.k[idx + 1]
        return 'K(' .. tostring(k) .. ')'
    else
        return 'R' .. v
    end
end

local function disassemble(proto, indent)
    indent = indent or ''
    print(indent .. '=== proto: source=' .. tostring(proto.source) ..
        ' maxstack=' .. proto.maxstacksize ..
        ' sizecode=' .. proto.sizecode ..
        ' sizek=' .. proto.sizek .. ' ===')
    for i = 1, #proto.code do
        local ins = proto.code[i]
        local op = luac.GET_OPCODE(ins)
        local name = luac.OPCODE_NAMES[op + 1] or ('OP' .. op)
        local a = luac.GETARG_A(ins)
        local line = string.format('%s%3d [%02d] %-12s A=%d', indent, i - 1, op, name, a)
        if op == luac.OP_LOADK or op == luac.OP_LOADKX then
            local bx = luac.GETARG_Bx(ins)
            line = line .. string.format(' Bx=%d K(%s)', bx, tostring(proto.k[bx + 1]))
        elseif op == luac.OP_NEWTABLE then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            line = line .. string.format(' B=%d C=%d', b, c)
        elseif op == luac.OP_GETTABLE or op == luac.OP_SETTABLE
            or op == luac.OP_GETTABUP or op == luac.OP_SETTABUP then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            line = line .. string.format(' B=%s C=%s', fmt_operand(b, proto), fmt_operand(c, proto))
        elseif op == luac.OP_SELF then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            line = line .. string.format(' B=R%d C=%s', b, fmt_operand(c, proto))
        elseif op == luac.OP_SETLIST then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            line = line .. string.format(' B=%d C=%d', b, c)
        elseif op == luac.OP_JMP or op == luac.OP_FORLOOP
            or op == luac.OP_FORPREP or op == luac.OP_TFORLOOP then
            local sbx = luac.GETARG_sBx(ins)
            line = line .. string.format(' sBx=%d -> %d', sbx, i + sbx)
        elseif op == luac.OP_CLOSURE then
            local bx = luac.GETARG_Bx(ins)
            line = line .. string.format(' Bx=%d', bx)
        elseif op == luac.OP_CALL or op == luac.OP_TAILCALL then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            line = line .. string.format(' B=%d C=%d', b, c)
        elseif op == luac.OP_MOVE then
            local b = luac.GETARG_B(ins)
            line = line .. string.format(' B=R%d', b)
        elseif op == luac.OP_LOADBOOL then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            line = line .. string.format(' B=%d C=%d', b, c)
        elseif op == luac.OP_TEST or op == luac.OP_TESTSET then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            line = line .. string.format(' B=%d C=%d', b, c)
        else
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            if b > 0 or c > 0 then
                line = line .. string.format(' B=%d C=%d', b, c)
            end
        end
        print(line)
    end
    for i = 1, #proto.p do
        disassemble(proto.p[i], indent .. '  ')
    end
end

local function analyze(name, src)
    print('\n########################################')
    print('# ' .. name)
    print('########################################')
    print('SOURCE:')
    print(src)
    print('---')
    local func = load(src)
    local shell = string.dump(func)
    local bc = string.dec(shell)
    local proto = luac.undump(bc, false)
    disassemble(proto)
end

-- 1. 空表
analyze('空表', [[
local t = {}
return t
]])

-- 2. 数组式初始化
analyze('数组初始化', [[
local t = {1, 2, 3, 4, 5}
return t
]])

-- 3. 记录式初始化
analyze('记录初始化', [[
local t = {a = 1, b = 2, c = 3}
return t
]])

-- 4. 混合初始化
analyze('混合初始化', [[
local t = {1, 2, x = 3, 4, y = 5}
return t
]])

-- 5. 表读
analyze('表读 GETTABLE', [[
local t = {a = 1}
local x = t.a
local y = t["b"]
local z = t[1]
return x, y, z
]])

-- 6. 表写
analyze('表写 SETTABLE', [[
local t = {}
t.a = 1
t["b"] = 2
t[3] = 4
return t
]])

-- 7. 方法调用 SELF
analyze('方法调用 SELF', [[
local t = {x = 1}
function t:foo(n) return self.x + n end
return t:foo(10)
]])

-- 8. 表嵌套
analyze('嵌套表', [[
local t = {a = {b = {c = 1}}}
return t.a.b.c
]])

-- 9. 元表
analyze('元表', [[
local t = setmetatable({}, {__index = function() return 42 end})
return t.anything
]])

-- 10. 大数组（SETLIST 多批）
analyze('大数组 SETLIST', [[
local t = {
    1,2,3,4,5,6,7,8,9,10,
    11,12,13,14,15,16,17,18,19,20,
    21,22,23,24,25,26,27,28,29,30,
    31,32,33,34,35,36,37,38,39,40,
    41,42,43,44,45,46,47,48,49,50,
}
return #t
]])

-- 11. upvalue 表读写
analyze('upvalue表读写', [[
local t = {}
local function f()
    t.a = 1
    return t.b
end
return f
]])

-- 12. 表构造函数中的函数
analyze('表中函数', [[
local t = {
    add = function(a, b) return a + b end,
    sub = function(a, b) return a - b end,
}
return t.add(1, 2)
]])
