local f = io.open('C:/Users/ruilo/Downloads/main(3).lua', 'rb')
local data = f:read('*a')
f:close()
print('data size:', #data, 'first:', data:sub(1,1))

local func = load(data)
print('load result:', type(func))
if func then
    print('calling...')
    local ok, err = pcall(func)
    print('call ok:', ok, 'err:', err)
end
