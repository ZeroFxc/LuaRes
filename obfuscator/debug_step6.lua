local str_encrypt = require('str_encrypt')
local luac = require('luac')

local function test(name, src, expected)
    io.write(string.format('%-45s ', name))
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

-- main 1字符串 + greet 1字符串 + for
test('main1+greet1+for', [[
local function greet(name)
    return "hi " .. name
end
local total = 0
for i = 1, 5 do total = total + i end
return greet("x") .. " done"
]], 'hi x done')

-- main 1字符串 + greet 1字符串 + 无for
test('main1+greet1+nofor', [[
local function greet(name)
    return "hi " .. name
end
return greet("x") .. " done"
]], 'hi x done')

-- main 2字符串 + greet 1字符串 + for
test('main2+greet1+for', [[
local function greet(name)
    return "hi " .. name
end
local total = 0
for i = 1, 5 do total = total + i end
return greet("x") .. " a" .. " b"
]], 'hi x a b')

-- 无函数 + main 3字符串 + for
test('nofunc+main3+for', [[
local total = 0
for i = 1, 5 do total = total + i end
return "a" .. " b" .. total .. " c"
]], 'a b15 c')
