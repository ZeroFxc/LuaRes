-- vararg tests
local function varargB0(a, ...)
    local t = {...}
    return #t, t[1], t[2], t[3]
end

local function varargB2(a, ...)
    local x = ...
    return x
end

local function varargB3(a, ...)
    local x, y = ...
    return x, y
end

local v1, v2, v3, v4 = varargB0(1, 10, 20, 30)
print("varargB0:", v1, v2, v3, v4)

local v5 = varargB2(1, 100)
print("varargB2:", v5)

local v6, v7 = varargB3(1, 10, 20)
print("varargB3:", v6, v7)

if v1 ~= 3 or v2 ~= 10 or v3 ~= 20 or v4 ~= 30 or
   v5 ~= 100 or v6 ~= 10 or v7 ~= 20 then
    print("VARARG TEST FAILED")
else
    print("VARARG TEST PASSED")
end

print("done")
