local f = io.open('C:/Users/ruilo/Downloads/main(3).lua', 'rb')
local data = f:read('*a')
f:close()

-- andlua 原生 load（自动解密）
local func = load(data)
if not func then
    print('load failed')
    return
end
print('load ok, type:', type(func))

-- 重新 dump
local dumped = string.dump(func)
print('dumped size:', #dumped, 'first byte:', string.byte(dumped, 1))

-- 用 luaclib 加载 dump 后的字节码
local luac = require('luac')
local ok, proto = pcall(luac.undump, dumped, false)
print('luac.undump ok:', ok)
if ok then
    print('proto sizecode:', proto.sizecode, 'sizek:', #proto.k, 'sizep:', #proto.p)
    -- 重新 dump 验证
    local out = luac.dump(proto)
    print('redump size:', #out)
else
    print('err:', proto)
end
