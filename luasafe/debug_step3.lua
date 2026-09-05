local str_encrypt = require('str_encrypt')
local luac = require('luac')

local function test(name, src, expected)
    io.write(string.format('%-35s ', name))
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

-- greet + main多字符串（无 factorial）
test('greet+multistr', [[
local function greet(name)
    return "hello, " .. name .. "!"
end
local msg = greet("world")
return msg .. " total=" .. 30 .. " fact=" .. 120
]], 'hello, world! total=30 fact=120')

-- 无函数，只有多字符串拼接
test('multistr only', [[
local a = "hello"
local b = "world"
return a .. " " .. b .. " " .. 42
]], 'hello world 42')

-- greet + 2个字符串常量
test('greet+2str', [[
local function greet(name)
    return "hi " .. name
end
return greet("x") .. " y" .. " z"
]], 'hi x y z')
