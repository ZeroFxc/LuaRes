local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.luac_obfuscate_c(p)
io.write("sizek="..p.sizek.."\n")
for i = 0, math.min(p.sizek-1, 95) do
    local k = p.k[i]
    local t = type(k)
    if t == "string" then
        io.write(string.format("k[%d]=string len=%d first=%q\n", i, #k, k:sub(1,20)))
    elseif t == "number" then
        io.write(string.format("k[%d]=number %s\n", i, tostring(k)))
    elseif t == "boolean" then
        io.write(string.format("k[%d]=bool %s\n", i, tostring(k)))
    else
        io.write(string.format("k[%d]=%s\n", i, t))
    end
end
io.flush()
