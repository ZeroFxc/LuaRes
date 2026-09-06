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

-- 2函数 + for + 多字符串拼接
test('2func+for+multistr', [[
local function add(a, b) return a + b end
local function greet(name)
    return "hello, " .. name .. "!"
end
local total = 0
for i = 1, 10 do total = add(total, i) end
local msg = greet("world")
return msg .. " t=" .. total .. " end"
]], 'hello, world! t=55 end')

-- 2函数 + 无for + 多字符串拼接
test('2func+multistr', [[
local function add(a, b) return a + b end
local function greet(name)
    return "hello, " .. name .. "!"
end
local msg = greet("world")
local total = add(30, 25)
return msg .. " t=" .. total .. " end"
]], 'hello, world! t=55 end')

-- 3函数 + 无for + 多字符串
test('3func+multistr', [[
local function add(a, b) return a + b end
local function mul(a, b) return a * b end
local function greet(name)
    return "hello, " .. name .. "!"
end
local msg = greet("world")
local total = add(30, 25)
local product = mul(3, 4)
return msg .. " t=" .. total .. " p=" .. product
]], 'hello, world! t=55 p=12')
