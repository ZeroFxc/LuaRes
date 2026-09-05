local f = io.open('flatten_output.luac', 'rb')
local bc = f:read('*a')
f:close()
print('扁平化后字节码大小:', #bc, 'bytes')
local func = load(bc)
if not func then
    print('加载失败!')
else
    print('加载成功')
    print('func(5,3) =', func(5,3), '(expect 8)')
    print('func(3,5) =', func(3,5), '(expect -2)')
    print('func(4,4) =', func(4,4), '(expect 16)')
    print('func(1,2) =', func(1,2), '(expect -1)')
    print('func(10,20) =', func(10,20), '(expect -10)')
end
