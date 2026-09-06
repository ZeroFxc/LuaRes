package.path = package.path .. ";E:/LuaRes/luatools/?.lua"
local luac = require('luac')
local str_encrypt = require('str_encrypt')

-- 最小测试: 只 SETTABLE 不 GETTABLE
local src = "local t={}; t.key='value'; print(t.key)"
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print("=== original ===")
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    print(string.format("  [%d] op=%d A=%d B=%d C=%d", i, op,
        luac.GETARG_A(proto.code[i]), luac.GETARG_B(proto.code[i]), luac.GETARG_C(proto.code[i])))
end
print("maxstacksize=", proto.maxstacksize)

str_encrypt.encrypt(proto, {key=0x55})

print("=== encrypted ===")
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    print(string.format("  [%d] op=%d A=%d B=%d C=%d", i, op,
        luac.GETARG_A(proto.code[i]), luac.GETARG_B(proto.code[i]), luac.GETARG_C(proto.code[i])))
end
print("maxstacksize=", proto.maxstacksize)

local out = luac.dump(proto)
local f2 = load(out)
print("=== run ===")
f2()
