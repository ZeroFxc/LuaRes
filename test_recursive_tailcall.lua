-- recursive tailcall test
local function tailSum(n, acc)
    if n <= 0 then return acc end
    return tailSum(n - 1, acc + n)
end
local sum = tailSum(5, 0)
print("recursive tailcall sum:", sum)
if sum ~= 15 then
    print("RECURSIVE TAILCALL TEST FAILED")
else
    print("RECURSIVE TAILCALL TEST PASSED")
end

-- call with c=0 test
local function callC0()
    return 1, 2, 3
end
local c1, c2, c3 = callC0()
print("callC0:", c1, c2, c3)
if c1 ~= 1 or c2 ~= 2 or c3 ~= 3 then
    print("CALLC0 TEST FAILED")
else
    print("CALLC0 TEST PASSED")
end

print("done")
