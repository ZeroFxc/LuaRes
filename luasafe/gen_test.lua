-- gen_test.lua - generate test bytecode
local f = function(a, b)
    local x = a + b
    local s = "hello"
    for i = 1, 10 do
        x = x + i
    end
    if x > 50 then
        return s .. " big"
    else
        return s .. " small"
    end
end

local bc = string.dec(string.dump(f))
local out = io.open("test_input.luac", "wb")
out:write(bc)
out:close()
print("Generated test_input.luac", #bc, "bytes")
print("Original result:", f(3, 5))
