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

-- 2函数 + for + main 1字符串
test('2func+for+main1', [[
local function add(a, b) return a + b end
local function greet(name) return "hi " .. name end
local total = 0
for i = 1, 5 do total = add(total, i) end
return greet("x") .. total
]], 'hi x15')

-- 2函数 + for + main 2字符串
test('2func+for+main2', [[
local function add(a, b) return a + b end
local function greet(name) return "hi " .. name end
local total = 0
for i = 1, 5 do total = add(total, i) end
return greet("x") .. total .. " done"
]], 'hi x15 done')

-- 2函数 + for + main 3字符串
test('2func+for+main3', [[
local function add(a, b) return a + b end
local function greet(name) return "hi " .. name end
local total = 0
for i = 1, 5 do total = add(total, i) end
return greet("x") .. " a" .. total .. " b"
]], 'hi x a15 b')

-- 2函数 + 无for + main 3字符串
test('2func+nofor+main3', [[
local function add(a, b) return a + b end
local function greet(name) return "hi " .. name end
local total = add(10, 5)
return greet("x") .. " a" .. total .. " b"
]], 'hi x a15 b')
