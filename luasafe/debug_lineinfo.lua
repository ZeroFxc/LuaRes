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
print('main code:', #proto.code, 'lineinfo:', #(proto.lineinfo or {}))

str_encrypt.encrypt(proto, {key=0x55})

print()
print('=== After ===')
print('main code:', #proto.code, 'lineinfo:', #(proto.lineinfo or {}))
print('greet code:', #proto.p[2].code, 'lineinfo:', #(proto.p[2].lineinfo or {}))

-- 检查 lineinfo 的内容
if proto.lineinfo then
    print('main lineinfo length:', #proto.lineinfo)
    for i = 1, math.min(5, #proto.lineinfo) do
        print('  lineinfo[' .. i .. ']:', proto.lineinfo[i])
    end
end
