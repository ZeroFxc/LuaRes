-- Test: nested table function reading upvalue
local stored = "initial"

outer = {
    inner = {
        get_and_clear = function()
            local v = stored
            stored = "cleared"
            return v
        end
    }
}

-- Test 1: direct call
print("=== Test 1: direct call ===")
stored = "test_value"
local r1 = outer.inner.get_and_clear()
print("result:", r1, "stored:", stored)
assert(r1 == "test_value", "Expected test_value, got: " .. tostring(r1))
assert(stored == "cleared", "Expected cleared, got: " .. tostring(stored))
print("PASS")

-- Test 2: call through local function
print("\n=== Test 2: call through local function ===")
local function call_it()
    return outer.inner.get_and_clear()
end
stored = "via_local"
local r2 = call_it()
print("result:", r2, "stored:", stored)
assert(r2 == "via_local", "Expected via_local, got: " .. tostring(r2))
print("PASS")

-- Test 3: string method on result
print("\n=== Test 3: string method on result ===")
stored = "HelloWorld"
local r3 = outer.inner.get_and_clear()
local upper = r3:upper()
local gsubbed = r3:gsub("o", "0")
print("upper:", upper, "gsubbed:", gsubbed)
assert(upper == "HELLOWORLD", "Expected HELLOWORLD, got: " .. tostring(upper))
print("PASS")

print("\n=== ALL TESTS PASSED ===")
