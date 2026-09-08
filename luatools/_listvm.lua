local luac = require("luac")
for k, v in pairs(luac) do
    if k:find("vm") or k:find("embed") then
        print(k, type(v))
    end
end
