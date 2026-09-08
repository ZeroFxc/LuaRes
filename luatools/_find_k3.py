s = open(r'E:\LuaRes\a_vm.lua', encoding='utf-8').read()
import re
matches = list(re.finditer(r'k=\{([^}]*)\}', s))
for i, m in enumerate(matches):
    content = m.group(1)
    if len(content) > 100:
        print(f'=== k[{i}] at {m.start()}, len={len(content)} ===')
        print(content[:1000])
        print('...')
        print(content[-200:])
        print()
