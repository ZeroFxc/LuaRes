package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local ch = require('const_hide')

local src = 'local t={v=10} function t:f(n) return self.v+n end return t:f(5)'
local proto = luac.undump(string.dec(string.dump(load(src))), false)

print("=== main constants before ===")
for i = 1, #proto.k do print(string.format("K%d: %s = %s", i-1, type(proto.k[i]), tostring(proto.k[i]))) end

ch.process(proto)

print("\n=== main code after ===")
for i = 1, #proto.code do
    local op = luac.GET_OPCODE(proto.code[i])
    local a = luac.GETARG_A(proto.code[i])
    local b = luac.GETARG_B(proto.code[i])
    local c = luac.GETARG_C(proto.code[i])
    local bx = luac.GETARG_Bx(proto.code[i])
    local names = {[0]='MOVE',[1]='LOADK',[5]='GETUPVAL',[6]='GETTABUP',[7]='GETTABLE',[8]='SETTABUP',[10]='SETTABLE',[11]='NEWTABLE',[12]='SELF',[36]='CALL',[37]='TAILCALL',[38]='RETURN',[44]='CLOSURE'}
    print(string.format("%3d: %-10s A=%d B=%d C=%d Bx=%d", i, names[op] or op, a, b, c, bx))
end

print("\n=== main constants after ===")
for i = 1, #proto.k do
    local v = proto.k[i]
    if type(v) == 'string' then print(string.format("K%d: string len=%d '%s'", i-1, #v, v))
    else print(string.format("K%d: %s = %s", i-1, type(v), tostring(v))) end
end

print("\n=== sub-proto code (t:f) ===")
local sp = proto.p[1]
for i = 1, #sp.code do
    local op = luac.GET_OPCODE(sp.code[i])
    local a = luac.GETARG_A(sp.code[i])
    local b = luac.GETARG_B(sp.code[i])
    local c = luac.GETARG_C(sp.code[i])
    local names = {[0]='MOVE',[1]='LOADK',[5]='GETUPVAL',[6]='GETTABUP',[7]='GETTABLE',[12]='SELF',[13]='ADD',[38]='RETURN'}
    print(string.format("%3d: %-10s A=%d B=%d C=%d", i, names[op] or op, a, b, c))
end
print("sub constants:")
for i = 1, #sp.k do print(string.format("  K%d: %s = %s", i-1, type(sp.k[i]), tostring(sp.k[i]))) end

local ok, r = pcall(function() return load(luac.dump(proto))() end)
print("\n=== EXECUTE: ok=" .. tostring(ok) .. " result=" .. tostring(r))
