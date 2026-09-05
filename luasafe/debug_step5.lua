local str_encrypt = require('str_encrypt')
local luac = require('luac')

local function test(name, src, expected)
    io.write(string.format('%-40s ', name))
    io.flush()
    local func = load(src)
    local bc = string.dec(string.dump(func))
    local proto = luac.undump(bc, false)
    str_encrypt.encrypt(proto, {key=0x55})
    local enc_bc = luac.dump(proto)
    local ok, f = pcall(load, enc_bc)
    if not ok then print('LOAD FAIL: ' .. tostring(f)); return end
    local ok2, result = pcall(f)
    if not ok2 then print('RUN FAIL: ' .. tostring(result)); return end
    if tostring(result) == expected then print('PASS')
    else print('WRONG: ' .. tostring(result) .. ' (expected ' .. expected .. ')') end
end

-- for循环 + 多字符串（无函数调用）
test('for+multistr', [[
local total = 0
for i = 1, 10 do total = total + i end
return "a" .. " b" .. total .. " c"
]], 'a b55 c')

-- for循环 + 1字符串
test('for+1str', [[
local total = 0
for i = 1, 10 do total = total + i end
return "result=" .. total
]], 'result=55')

-- for循环 + 2字符串
test('for+2str', [[
local total = 0
for i = 1, 10 do total = total + i end
return "a" .. total .. "b"
]], 'a55b')
