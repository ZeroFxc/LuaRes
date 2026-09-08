local luac = require("luac")
luac.srand(42)

local f = io.open("../a_vm.lua", "rb")
local src = f:read("*a")
f:close()

local fn = load(src)
local bc = string.dec(string.dump(fn, true))
print("Original bc size:", #bc)

local p = luac.undump(bc, false)
print("Proto loaded")

-- Dump and check
local dumped = luac.dump(p)
print("Dumped bc size:", #dumped)

-- Compare first 100 bytes
print("First 20 bytes original:", string.byte(bc, 1, 20))
print("First 20 bytes dumped:  ", string.byte(dumped, 1, 20))

-- Check if they are identical
if bc == dumped then
    print("IDENTICAL")
else
    print("DIFFERENT")
    -- Find first difference
    for i = 1, math.min(#bc, #dumped) do
        if string.byte(bc, i) ~= string.byte(dumped, i) then
            print("First diff at byte", i, ":", string.byte(bc, i), "vs", string.byte(dumped, i))
            break
        end
    end
end
