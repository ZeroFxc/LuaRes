-- gen_flatten_test.lua - generate test bytecode with control flow
local f = function(a, b)
    local x = 0
    if a > b then
        x = a + b
    elseif a < b then
        x = a - b
    else
        x = a * b
    end
    if x > 10 then
        x = x + 100
    end
    return x
end

local bc = string.dec(string.dump(f))
local out = io.open("flatten_input.luac", "wb")
out:write(bc)
out:close()
print("Generated flatten_input.luac", #bc, "bytes")
print("Test results:")
print("  f(5,3) =", f(5,3), "(expect 108)")
print("  f(3,5) =", f(3,5), "(expect -2)")
print("  f(4,4) =", f(4,4), "(expect 116)")
print("  f(1,2) =", f(1,2), "(expect -1)")
