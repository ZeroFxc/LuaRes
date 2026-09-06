package.path = package.path
    .. ";E:/LuaRes/luatools/forward/?.lua"
    .. ";E:/LuaRes/luatools/reverse/?.lua"
    .. ";E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')
local se = require('str_encrypt')

math.randomseed(12345)
local src = 'local a="hello" local b="world" return a..b'
local proto = luac.undump(string.dec(string.dump(load(src))), false)

print('=== 原始 ===')
print('maxstack=' .. proto.maxstacksize .. ' code=' .. #proto.code .. ' k=' .. #proto.k)
for i = 1, #proto.k do print('  k[' .. (i-1) .. '] = ' .. tostring(proto.k[i])) end
for i = 1, #proto.code do
    local ins = proto.code[i]
    local op = luac.GET_OPCODE(ins)
    print(string.format('  %2d op=%d A=%d B=%d C=%d', i-1, op, luac.GETARG_A(ins), luac.GETARG_B(ins), luac.GETARG_C(ins)))
end

se.encrypt(proto, {})

print('\n=== 加密后 ===')
print('maxstack=' .. proto.maxstacksize .. ' code=' .. #proto.code .. ' k=' .. #proto.k .. ' p=' .. #proto.p)
for i = 1, #proto.k do
    local v = proto.k[i]
    if type(v) == 'string' then
        local bytes = {}
        for j = 1, math.min(#v, 10) do bytes[j] = string.byte(v, j) end
        print('  k[' .. (i-1) .. '] = string(len=' .. #v .. ') [' .. table.concat(bytes, ',') .. ']')
    else
        print('  k[' .. (i-1) .. '] = ' .. tostring(v))
    end
end
for i = 1, #proto.code do
    local ins = proto.code[i]
    local op = luac.GET_OPCODE(ins)
    local nm = ({[0]='MOVE',[1]='LOADK',[36]='CALL',[38]='RETURN',[44]='CLOSURE',[41]='CONCAT'})[op] or ('OP'..op)
    print(string.format('  %2d %-8s A=%d B=%d C=%d', i-1, nm, luac.GETARG_A(ins), luac.GETARG_B(ins), luac.GETARG_C(ins)))
end

print('\n=== 执行 ===')
local ok, r = pcall(function() return load(luac.dump(proto))() end)
print('result:', ok, tostring(r))
