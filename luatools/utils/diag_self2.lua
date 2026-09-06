package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local str_encrypt = require('str_encrypt')
local destr = require('destr_encrypt')

local src = 'local t={v=10} function t:f(n) return self.v+n end return t:f(5)'
local proto = luac.undump(string.dec(string.dump(load(src))), false)

str_encrypt.encrypt_function(proto, {})
print("=== FORWARD done, sub-protos: " .. #proto.p)

local n = destr.clean_function(proto)
print("=== REVERSE cleaned: " .. n)

print("=== AFTER REVERSE code ===")
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local b = luac.GETARG_B(proto.code[i])
    local c = luac.GETARG_C(proto.code[i])
    local bx = luac.GETARG_Bx(proto.code[i])
    local desc = string.format("%3d: op=%d A=%d B=%d C=%d", i, op, a, b, c)
    if op == 1 then desc = desc .. " LOADK K" .. bx end
    if op == 10 then desc = desc .. " SETTABLE" end
    if op == 12 then desc = desc .. " SELF" end
    if op == 36 then desc = desc .. " CALL" end
    if op == 44 then desc = desc .. " CLOSURE p" .. bx end
    print(desc)
end

print("=== constants ===")
for i = 1, #proto.k do
    local v = proto.k[i]
    if type(v) == 'string' then
        print(string.format("K%d: string '%s' len=%d", i-1, v, #v))
    else
        print(string.format("K%d: %s = %s", i-1, type(v), tostring(v)))
    end
end

print("=== sub-protos: " .. #proto.p)

-- Try to execute
local ok, r = pcall(function() return load(luac.dump(proto))() end)
print("=== EXECUTE: ok=" .. tostring(ok) .. " result=" .. tostring(r))
