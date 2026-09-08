s = open(r'E:\LuaRes\a_vm.lua', encoding='utf-8').read()
# Find proto definition
for keyword in ['proto =', 'proto={', 'local proto', '_proto', 'PROTO']:
    idx = s.find(keyword)
    if idx >= 0:
        print(f'Found "{keyword}" at {idx}')
        print(repr(s[idx:idx+300]))
        print('---')
        break
# Also look at the end of file where data might be
print('\n=== Last 500 chars ===')
print(repr(s[-500:]))
