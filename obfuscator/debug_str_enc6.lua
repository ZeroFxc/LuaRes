package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/reverse/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local str_encrypt = require('str_encrypt')

-- 测试整数 key
local src = "local t={}; t[1]='value'; print(t[1])"
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

str_encrypt.encrypt(proto, {key=0x55})

local out = luac.dump(proto)
local f2 = load(out)
print("int key result:")
f2()

-- 测试字符串 key 但不用 str_encrypt 处理 SETTABLE
-- 手动验证
print("---")
local src2 = "local t={}; t['key']='value'; print(t['key'])"
local func2 = load(src2)
local bc2 = string.dec(string.dump(func2))
local proto2 = luac.undump(bc2, false)

-- 只加密字符串，不替换指令（手动）
for i = 1, #proto2.k do
    if type(proto2.k[i]) == 'string' then
        local bytes = {}
        for j = 1, #proto2.k[i] do
            bytes[j] = string.char(string.byte(proto2.k[i], j) ~ 0x55)
        end
        proto2.k[i] = table.concat(bytes)
    end
end

local out2 = luac.dump(proto2)
print("encrypted constants, no instruction replacement:")
local ok, err = pcall(function() load(out2)() end)
print("ok=", ok, "err=", err)
