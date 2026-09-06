package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/reverse/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local str_encrypt = require('str_encrypt')

local src = "local t={}; t[1]='value'; print(t[1])"
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print("=== before encrypt ===")
for i = 1, #proto.k do
    print("  k["..i.."] type="..type(proto.k[i]).." val="..tostring(proto.k[i]))
end

str_encrypt.encrypt(proto, {key=0x55})

print("=== after encrypt (before dump) ===")
for i = 1, #proto.k do
    print("  k["..i.."] type="..type(proto.k[i]).." val="..tostring(proto.k[i]))
end

local out = luac.dump(proto)

-- 重新加载检查
local proto2 = luac.undump(out, false)
print("=== after dump+undump ===")
for i = 1, #proto2.k do
    print("  k["..i.."] type="..type(proto2.k[i]).." val="..tostring(proto2.k[i]))
end
