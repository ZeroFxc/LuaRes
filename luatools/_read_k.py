s = open(r'E:\LuaRes\a_vm.lua', encoding='utf-8').read()
lines = s.split('\n')
print(f'Total lines: {len(lines)}')
for i, line in enumerate(lines):
    if 'k={' in line and len(line) > 1000:
        print(f'Line {i}: len={len(line)}')
        # Find k={ position
        kidx = line.find('k={')
        print(f'k= at char {kidx}')
        # Print from k={ to next },
        endidx = line.find('},', kidx)
        print(f'k array ends at {endidx}')
        kcontent = line[kidx:endidx+2]
        print(f'k array length: {len(kcontent)}')
        print('First 500 chars:')
        print(kcontent[:500])
        print('...')
        print('Last 500 chars:')
        print(kcontent[-500:])
        break
