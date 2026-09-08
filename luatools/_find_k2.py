s = open(r'E:\LuaRes\a_vm.lua', encoding='utf-8').read()
# Find all k={...} arrays
import re
# Find k={ with non-empty content
matches = list(re.finditer(r'k=\{([^}]*)\}', s))
print(f'Found {len(matches)} k arrays')
for i, m in enumerate(matches):
    content = m.group(1)
    if content.strip():
        print(f'k[{i}] at {m.start()}: {content[:300]}')
        print('---')
