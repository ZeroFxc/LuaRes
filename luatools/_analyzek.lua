-- load the generated VM source and extract proto
local src = io.open("_vmout.lua", "r"):read("*a")
-- find k={...}
local kstart = src:find("k={", 1, true)
local kend = src:find("},", kstart, true)
local kstr = src:sub(kstart+3, kend-1)
-- parse constants (simple: split by comma, but strings may contain commas)
-- just count nils
local nilcount = 0
local niltotal = 0
local i = 1
local depth = 0
local instr_count = 0
while i <= #kstr do
    local c = kstr:sub(i,i)
    if c == "{" then depth = depth + 1
    elseif c == "}" then depth = depth - 1
    elseif c == "," and depth == 0 then
        niltotal = niltotal + 1
        local item = kstr:sub(1, i-1):match("([^,]+)$") or ""
        if item == "nil" then nilcount = nilcount + 1 end
    end
    i = i + 1
end
niltotal = niltotal + 1
print("total constants: "..niltotal..", nil constants: "..nilcount)
-- find nil positions
local pos = 1
local idx = 0
for item in kstr:gmatch("[^,]+") do
    if item == "nil" then
        print("  nil at k["..idx.."]")
    end
    idx = idx + 1
end
