-- Test: callback stored in global, called by host after main chunk ends
local counter = 0
local field = 1
_G._test_callback = function()
    counter = counter + 1
    if field == 1 then field = 2 else field = 1 end
    return counter, field
end
print("main chunk done, counter=", counter, "field=", field)
