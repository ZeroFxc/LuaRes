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

-- greet无字符串 + dummy有字符串(不调用) + for + main2字符串
test('greet-nostr+dummy-str+for+main2', [[
local function add(a, b) return a + b end
local function greet(name) return name end
local function dummy() return "unused string" end
local total = 0
for i = 1, 5 do total = add(total, i) end
return greet("x") .. total .. " done"
]], 'x15 done')

-- greet有字符串 + dummy无字符串 + for + main2字符串
test('greet-str+dummy-nostr+for+main2', [[
local function add(a, b) return a + b end
local function greet(name) return "hi " .. name end
local function dummy() return 42 end
local total = 0
for i = 1, 5 do total = add(total, i) end
return greet("x") .. total .. " done"
]], 'hi x15 done')

-- 2个有字符串的函数 + for + main1字符串
test('2strfunc+for+main1', [[
local function greet1(name) return "a " .. name end
local function greet2(name) return "b " .. name end
local total = 0
for i = 1, 5 do total = total + i end
return greet1("x") .. total
]], 'a x15')
