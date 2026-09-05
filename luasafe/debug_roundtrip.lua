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

str_encrypt.encrypt(proto, {key=0x55})

-- dump 后重新 undump
local enc_bc = luac.dump(proto)
local proto2 = luac.undump(enc_bc, false)

print('=== After dump->undump ===')
print('main sizep:', #proto2.p, 'sizek:', #proto2.k, 'code:', #proto2.code)
for i = 1, #proto2.p do
    local p = proto2.p[i]
    print(string.format('  p[%d]: sizek=%d code=%d sizep=%d maxstack=%d', i, #p.k, #p.code, #p.p, p.maxstacksize))
    -- 检查常量
    for j = 1, #p.k do
        print(string.format('    k[%d]: %s = %s', j, type(p.k[j]), tostring(p.k[j])))
    end
    -- 检查子 proto
    for j = 1, #p.p do
        local sp = p.p[j]
        print(string.format('    subp[%d]: sizek=%d code=%d maxstack=%d', j, #sp.k, #sp.code, sp.maxstacksize))
    end
end

-- 尝试运行
print()
print('=== Running re-loaded proto ===')
local f = load(enc_bc)
local ok, result = pcall(f)
print('Result:', tostring(result))
