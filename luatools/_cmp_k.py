def get_k_array(path):
    s = open(path, encoding='utf-8', errors='replace').read()
    lines = s.split('\n')
    for i, line in enumerate(lines):
        if 'k={' in line and len(line) > 100:
            kidx = line.find('k={')
            endidx = line.find('},', kidx)
            return line[kidx:endidx+2]
    return None

k1 = get_k_array(r'E:\LuaRes\a_vm.lua')
k2 = get_k_array(r'E:\LuaRes\luatools\_nested_vmonly.lua')

print('=== a_vm.lua K array (last 400 chars) ===')
print(k1[-400:] if k1 else 'NOT FOUND')
print()
print('=== _nested_vmonly.lua K array (last 400 chars) ===')
print(k2[-400:] if k2 else 'NOT FOUND')
print()
print('a_vm K length:', len(k1) if k1 else 0)
print('nested K length:', len(k2) if k2 else 0)
