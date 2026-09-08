s = open(r'E:\LuaRes\a_vm.lua', encoding='utf-8').read()
lines = s.split('\n')
line = lines[360]
print(f'Line 360 length: {len(line)}')
print(line)
