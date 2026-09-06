local f = io.open('test_output.luac', 'rb')
local bc = f:read('*a')
f:close()
print('混淆后字节码大小:', #bc, 'bytes')
local func = load(bc)
if not func then
    print('加载失败!')
else
    print('加载成功')
    print('执行 func(3,5):', func(3, 5))
    print('执行 func(1,1):', func(1, 1))
    print('执行 func(10,20):', func(10, 20))
end
