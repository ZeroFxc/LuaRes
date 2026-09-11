-- upvalue counters test
local function makeCounters()
    local counters = {}
    for i = 1, 3 do
        local count = 0
        counters[i] = function(inc)
            if inc then count = count + inc end
            return count
        end
    end
    return counters
end

local counters = makeCounters()
counters[1](10)
counters[1](13)
local up1 = counters[1]()
counters[2](20)
counters[2](13)
local up2 = counters[2]()

print("upvalue counters:", up1, up2)
if up1 ~= 23 or up2 ~= 33 then
    print("UPVALUE COUNTERS TEST FAILED")
else
    print("UPVALUE COUNTERS TEST PASSED")
end

print("done")
