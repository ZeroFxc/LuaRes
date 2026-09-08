local luac = require("luac")
local longstr = string.rep("AB", 100)
local code = 'print("' .. longstr .. '")'
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.str_encrypt_c(p)
-- check constants
print("sizek="..p.sizek)
for i=0,p.sizek-1 do
    local t = p.k_tag[i]
    local v
    if t == 3 then v = "num:"..tostring(p.k_num[i])
    elseif t == 4 then v = "str:"..tostring(p.k_str[i])
    elseif t == 1 then v = "bool:"..tostring(p.k_bool[i])
    elseif t == 0 then v = "nil"
    else v = "type:"..t end
    print("k["..i.."]="..v)
end
