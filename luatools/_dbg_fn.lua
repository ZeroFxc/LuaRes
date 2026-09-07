local luac = require("luac")
local f = loadfile("smoke_target.lua")
local bc = string.dec(string.dump(f, true))
local p = luac.undump(bc, false)

luac.num_obfuscate_c(p)
luac.const_hide_c(p)
luac.str_encrypt_c(p)

local d = luac.dump(p)
print("dump ok: " .. tostring(#d))

-- wrap to catch which function fails
local wrapped = [[
local results = {}
local ok, err = pcall(function()
    results.fact = fact(5)
    print("fact ok")
end)
if not ok then print("fact FAIL: " .. tostring(err)) end

ok, err = pcall(function()
    results.fib = fib(7)
    print("fib ok")
end)
if not ok then print("fib FAIL: " .. tostring(err)) end

ok, err = pcall(function()
    results.table = table_test()
    print("table ok")
end)
if not ok then print("table FAIL: " .. tostring(err)) end

ok, err = pcall(function()
    results.string = string_test()
    print("string ok")
end)
if not ok then print("string FAIL: " .. tostring(err)) end

ok, err = pcall(function()
    results.math = math_test()
    print("math ok")
end)
if not ok then print("math FAIL: " .. tostring(err)) end

ok, err = pcall(function()
    results.loop = loop_test()
    print("loop ok")
end)
if not ok then print("loop FAIL: " .. tostring(err)) end

ok, err = pcall(function()
    results.co = coroutine_test()
    print("co ok")
end)
if not ok then print("co FAIL: " .. tostring(err)) end

ok, err = pcall(function()
    results.closure = closure_test()
    print("closure ok")
end)
if not ok then print("closure FAIL: " .. tostring(err)) end

print("DONE")
]]

-- We can't easily inject this into the compiled bytecode.
-- Instead, just run and see the error.
local r = load(d)
if r then
    local ok, err = pcall(r)
    if not ok then print("RUNTIME ERROR: " .. tostring(err)) end
else
    print("LOAD_FAIL")
end
