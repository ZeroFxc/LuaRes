local src = io.open("_vmout.lua", "r"):read("*a")
-- find k={...} properly: from "k={" to the next "},\n" at same indent level
local kstart = src:find("k={", 1, true) + 2  -- after "k="
local ustart = src:find("upvalues={", kstart, true)
local kstr = src:sub(kstart, ustart-3)
-- remove outer braces
kstr = kstr:sub(2, -2)
-- parse constants carefully (strings may contain commas, use a simple state machine)
local constants = {}
local i = 1
local depth = 0
local current = ""
local in_str = false
local str_char = ""
while i <= #kstr do
    local c = kstr:sub(i,i)
    if in_str then
        current = current .. c
        if c == "\\" then
            current = current .. kstr:sub(i+1,i+1)
            i = i + 2
        elseif c == str_char then
            in_str = false
        end
        i = i + 1
    elseif c == "'" or c == '"' then
        in_str = true
        str_char = c
        current = current .. c
        i = i + 1
    elseif c == "," then
        constants[#constants+1] = current
        current = ""
        i = i + 1
    else
        current = current .. c
        i = i + 1
    end
end
if #current > 0 then constants[#constants+1] = current end
print("total constants: "..#constants)
-- check specific indices (0-indexed: 256,257,258,261,262,263,264)
for _, idx in ipairs({0,1,2,5,6,7,8,256,257,258,261,262,263,264}) do
    local v = constants[idx+1] or "OUT OF RANGE"
    local vshort = #v > 40 and v:sub(1,40).."..." or v
    print(string.format("  k[%d] = %s", idx, vshort))
end
