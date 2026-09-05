-- 组合测试：多种混淆模块的组合使用
local luac = require('luac')

-- 测试脚本：包含字符串、数字、布尔值、控制流
local test_src = [[
local function factorial(n)
    if n <= 1 then
        return 1
    end
    return n * factorial(n - 1)
end

local function is_even(n)
    return n % 2 == 0
end

local function greet(name)
    return "hello, " .. name .. "!"
end

local total = 0
for i = 1, 10 do
    if is_even(i) then
        total = total + i
    end
end

local msg = greet("world")
local fact = factorial(5)
return msg .. " total=" .. total .. " fact=" .. fact
]]

local function run_test(name, modules)
    io.write(string.format('%-40s ', name))
    io.flush()
    local func = load(test_src)
    local bc = string.dec(string.dump(func))
    local proto = luac.undump(bc, false)

    local ok, err = pcall(function()
        for _, mod in ipairs(modules) do
            mod.fn(proto, mod.options or {})
        end
    end)

    if not ok then
        print('OBFUSCATE FAILED: ' .. tostring(err))
        return false
    end

    local enc_bc = luac.dump(proto)
    local ok2, f = pcall(load, enc_bc)
    if not ok2 then
        print('LOAD FAILED: ' .. tostring(f))
        return false
    end

    local ok3, result = pcall(f)
    if not ok3 then
        print('RUN FAILED: ' .. tostring(result))
        return false
    end

    local expected = 'hello, world! total=30 fact=120'
    if result == expected then
        print('PASS (' .. #enc_bc .. ' bytes)')
        return true
    else
        print('WRONG RESULT: ' .. tostring(result))
        return false
    end
end

-- 加载所有模块
local str_encrypt = require('str_encrypt')
local num_obf = require('num_obfuscate')
local bool_obf = require('bool_obfuscate')
local const_poison = require('const_poison')

local pass = 0
local total = 0

-- 单个模块测试
total = total + 1; if run_test('str_encrypt', {{fn=str_encrypt.encrypt, options={key=0x55}}}) then pass = pass + 1 end
total = total + 1; if run_test('num_obfuscate', {{fn=num_obf.obfuscate, options={rate=1.0}}}) then pass = pass + 1 end
total = total + 1; if run_test('bool_obfuscate', {{fn=bool_obf.obfuscate, options={bool_const_rate=0.5, comparison_rate=0.5, test_double_rate=0.3}}}) then pass = pass + 1 end
total = total + 1; if run_test('const_poison', {{fn=const_poison.poison, options={count=20}}}) then pass = pass + 1 end

-- 两两组合
total = total + 1; if run_test('str + num', {
    {fn=str_encrypt.encrypt, options={key=0x55}},
    {fn=num_obf.obfuscate, options={rate=0.8}},
}) then pass = pass + 1 end

total = total + 1; if run_test('str + bool', {
    {fn=str_encrypt.encrypt, options={key=0x55}},
    {fn=bool_obf.obfuscate, options={bool_const_rate=0.5, comparison_rate=0.5}},
}) then pass = pass + 1 end

total = total + 1; if run_test('num + bool', {
    {fn=num_obf.obfuscate, options={rate=0.8}},
    {fn=bool_obf.obfuscate, options={bool_const_rate=0.5, comparison_rate=0.5}},
}) then pass = pass + 1 end

total = total + 1; if run_test('str + const_poison', {
    {fn=str_encrypt.encrypt, options={key=0x55}},
    {fn=const_poison.poison, options={count=20}},
}) then pass = pass + 1 end

-- 三组合
total = total + 1; if run_test('str + num + bool', {
    {fn=str_encrypt.encrypt, options={key=0x55}},
    {fn=num_obf.obfuscate, options={rate=0.8}},
    {fn=bool_obf.obfuscate, options={bool_const_rate=0.5, comparison_rate=0.5, test_double_rate=0.3}},
}) then pass = pass + 1 end

total = total + 1; if run_test('str + num + const_poison', {
    {fn=str_encrypt.encrypt, options={key=0x55}},
    {fn=num_obf.obfuscate, options={rate=0.8}},
    {fn=const_poison.poison, options={count=20}},
}) then pass = pass + 1 end

-- 四组合
total = total + 1; if run_test('str + num + bool + const_poison', {
    {fn=str_encrypt.encrypt, options={key=0x55}},
    {fn=num_obf.obfuscate, options={rate=0.8}},
    {fn=bool_obf.obfuscate, options={bool_const_rate=0.5, comparison_rate=0.5, test_double_rate=0.3}},
    {fn=const_poison.poison, options={count=20}},
}) then pass = pass + 1 end

print()
print(string.format('Total: %d/%d passed', pass, total))
