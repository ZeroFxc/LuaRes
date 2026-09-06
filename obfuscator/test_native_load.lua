local f = io.open('C:/Users/ruilo/Downloads/main(3).lua', 'rb')
local data = f:read('*a')
f:close()

-- 直接用 andlua 原生 load 加载（会自动 string.dec）
local ok, func = pcall(load, data)
print('native load ok:', ok)
if ok then
    print('func type:', type(func))
    -- 不执行，只看能否加载
else
    print('err:', func)
end
