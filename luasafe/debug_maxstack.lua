local str_encrypt = require('str_encrypt')
local luac = require('luac')

local src = [[
local function add(a, b) return a + b end
local function greet(name)
    return "hello, " .. name .. "!"
end
local total = 0
for i = 1, 10 do total = add(total, i) end
local msg = greet("world")
return msg .. " t=" .. total .. " end"
]]

local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('=== Before ===')
print('main maxstacksize:', proto.maxstacksize)
for i = 1, #proto.p do
    print('  p[' .. i .. '] maxstacksize:', proto.p[i].maxstacksize)
end

str_encrypt.encrypt(proto, {key=0x55})

print()
print('=== After ===')
print('main maxstacksize:', proto.maxstacksize)
for i = 1, #proto.p do
    print('  p[' .. i .. '] maxstacksize:', proto.p[i].maxstacksize)
    for j = 1, #proto.p[i].p do
        print('    p[' .. i .. '].p[' .. j .. '] maxstacksize:', proto.p[i].p[j].maxstacksize)
    end
end

-- 手动计算 main 实际使用的最大寄存器
print()
print('=== main actual max register ===')
local max_r = 0
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    if a > max_r then max_r = a end
    if op <= 46 then
        local b = luac.GETARG_B(proto.code[i])
        local c = luac.GETARG_C(proto.code[i])
        if b < 255 and b > max_r then max_r = b end
        if c < 255 and c > max_r then max_r = c end
    end
end
print('main actual max reg:', max_r, '(needs maxstacksize >=', max_r + 1, ')')
