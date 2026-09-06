package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/reverse/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local str_encrypt = require('str_encrypt')

local src = "print('hello')"
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print("before: sizek=", #proto.k)
for i = 1, #proto.k do
    print("  k["..i.."]="..tostring(proto.k[i]))
end

str_encrypt.encrypt(proto, {key=0x55})

print("after: sizek=", #proto.k)
for i = 1, #proto.k do
    print("  k["..i.."]="..tostring(proto.k[i]))
end
print("sizep=", #proto.p)
if #proto.p > 0 then
    local dec = proto.p[1]
    print("decrypt func sizek=", #dec.k)
    for i = 1, #dec.k do
        print("  dec.k["..i.."]="..tostring(dec.k[i]))
    end
end

-- 尝试运行
local out = luac.dump(proto)
local f2 = load(out)
local ok, err = pcall(f2)
print("run:", ok, err)
