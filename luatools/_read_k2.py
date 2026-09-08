s = open(r'E:\LuaRes\a_vm.lua', encoding='utf-8').read()
lines = s.split('\n')
print(f'Total lines: {len(lines)}')
for i, line in enumerate(lines):
    if 'k={' in line:
        print(f'Line {i}: len={len(line)}, contains k=')
        if len(line) > 200:
            kidx = line.find('k={')
            print(f'  k= at char {kidx}')
            print(f'  snippet: {line[kidx:kidx+200]}')
