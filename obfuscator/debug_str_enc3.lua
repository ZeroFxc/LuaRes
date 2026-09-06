package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/reverse/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local str_encrypt = require('str_encrypt')

-- 测试解密函数是否能正确工作
local src = "local s = 'hello'; print(s)"
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

str_encrypt.encrypt(proto, {key=0x55})

-- 手动检查解密函数
local dec = proto.p[1]
print("decrypt func:")
print("  numparams=", dec.numparams)
print("  maxstacksize=", dec.maxstacksize)
print("  sizecode=", #dec.code)
print("  constants:")
for i = 1, #dec.k do
    print("    k["..i.."]="..tostring(dec.k[i]))
end
print("  upvalues:", #dec.upvalues)
for i = 1, #dec.upvalues do
    print("    upval["..i.."] instack="..tostring(dec.upvalues[i].instack).." idx="..tostring(dec.upvalues[i].idx))
end

-- 运行
local out = luac.dump(proto)
local f2 = load(out)
print("run result:")
f2()
