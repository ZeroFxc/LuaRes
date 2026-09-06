package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/reverse/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local str_encrypt = require('str_encrypt')

local src = "local t={}; t[1]='value'; print(t[1])"
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print("=== original ===")
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    print(string.format("  [%d] op=%d A=%d B=%d C=%d", i, op,
        luac.GETARG_A(proto.code[i]), luac.GETARG_B(proto.code[i]), luac.GETARG_C(proto.code[i])))
end
print("constants:")
for i = 1, #proto.k do print("  k["..i.."]="..tostring(proto.k[i])) end

str_encrypt.encrypt(proto, {key=0x55})

print("=== encrypted ===")
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    print(string.format("  [%d] op=%d A=%d B=%d C=%d", i, op,
        luac.GETARG_A(proto.code[i]), luac.GETARG_B(proto.code[i]), luac.GETARG_C(proto.code[i])))
end
print("maxstacksize=", proto.maxstacksize)
