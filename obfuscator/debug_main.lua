local luac = require('luac')

-- 1. 读取 main.lua
local f = io.open('E:/LuaRes/main.lua', 'rb')
local data = f:read('*a')
f:close()
print('=== main.lua ===')
print('raw size:', #data, 'first byte:', string.byte(data, 1), string.char(string.byte(data,1)))

-- 2. string.dec 解密
local ok, dec = pcall(string.dec, data)
print('string.dec ok:', ok)
if ok then
    print('dec size:', #dec, 'first byte:', string.byte(dec, 1))
    -- 打印前16字节
    local hex = ''
    for i = 1, math.min(16, #dec) do hex = hex .. string.format('%02X ', string.byte(dec, i)) end
    print('dec first 16:', hex)
end

-- 3. andlua 原生 load
local func, err = load(dec)
print('native load:', func and 'OK' or ('FAIL: ' .. tostring(err)))

-- 4. luaclib undump
local ok2, proto = pcall(luac.undump, dec, false)
print('luac.undump:', ok2 and 'OK' or ('FAIL: ' .. tostring(proto)))
if ok2 then
    print('  main: sizecode=' .. proto.sizecode .. ' sizek=' .. #proto.k .. ' sizep=' .. #proto.p)
    -- 打印常量
    for i = 1, math.min(5, #proto.k) do
        local k = proto.k[i]
        if type(k) == 'string' then
            print('  k[' .. i .. '] str len=' .. #k .. ' preview=' .. k:sub(1, 40):gsub('\n', '\\n'))
        else
            print('  k[' .. i .. '] ' .. type(k) .. '=' .. tostring(k))
        end
    end
end
