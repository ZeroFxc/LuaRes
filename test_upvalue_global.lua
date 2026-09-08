-- Minimal test: function in global table accessing upvalue
local counter = 0

api = {
    get_value = function()
        counter = counter + 1
        return "hello" .. tostring(counter)
    end
}

local function test()
    local v = api.get_value()
    print("type:", type(v))
    print("value:", v)
    print("upper:", v:upper())
    print("gsub:", v:gsub("l", "L"))
    return v
end

local result = test()
print("result:", result)
assert(result == "hello1", "Expected hello1, got: " .. tostring(result))
print("PASS")
