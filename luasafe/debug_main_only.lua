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

-- 只加密 main，不加密子函数
print('=== Encrypting main only ===')
str_encrypt.encrypt_function(proto, {key=0x55})

local enc_bc = luac.dump(proto)
local ok, f = pcall(load, enc_bc)
if not ok then
    print('LOAD FAIL: ' .. tostring(f))
else
    local ok2, result = pcall(f)
    if not ok2 then
        print('RUN FAIL: ' .. tostring(result))
    else
        print('Result:', tostring(result), '(expected: hello, world! t=55 end)')
    end
end

-- 只加密子函数，不加密 main
print()
print('=== Encrypting sub functions only ===')
local func2 = load(src)
local bc2 = string.dec(string.dump(func2))
local proto2 = luac.undump(bc2, false)
for i = 1, #proto2.p do
    str_encrypt.encrypt_function(proto2.p[i], {key=0x55})
end

local enc_bc2 = luac.dump(proto2)
local ok3, f2 = pcall(load, enc_bc2)
if not ok3 then
    print('LOAD FAIL: ' .. tostring(f2))
else
    local ok4, result2 = pcall(f2)
    if not ok4 then
        print('RUN FAIL: ' .. tostring(result2))
    else
        print('Result:', tostring(result2), '(expected: hello, world! t=55 end)')
    end
end
