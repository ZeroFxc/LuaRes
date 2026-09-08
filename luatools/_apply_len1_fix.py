import re

# 1. luac.c
p = r'E:\LuaRes\luaclib\luac.c'
s = open(p, encoding='utf-8').read()
old = '        int valid = andlua_is_valid_text(tmp, len);'
new = '        int valid = (len == 1) || andlua_is_valid_text(tmp, len);'
if old in s:
    s = s.replace(old, new, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('luac.c: applied len==1 fix')
else:
    print('luac.c: already fixed or pattern not found')

# 2. vm_embed.c
p = r'E:\LuaRes\luaclib\vm_asm\vm_embed.c'
s = open(p, encoding='utf-8').read()
old = '        int valid = is_valid_text(tmp, len);'
new = '        int valid = (len == 1) || is_valid_text(tmp, len);'
if old in s:
    s = s.replace(old, new, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('vm_embed.c: applied len==1 fix')
else:
    print('vm_embed.c: already fixed or pattern not found')

# 3. lundump.c
p = r'E:\LuaRes\luasafe\lundump.c'
s = open(p, encoding='utf-8').read()
# Find the is_valid_text check in LoadString
matches = list(re.finditer(r'int valid = is_valid_text\([^)]+\);', s))
print(f'lundump.c: found {len(matches)} matches')
for m in matches:
    print(f'  line: {m.group()}')
# Replace all
s2 = re.sub(r'int valid = is_valid_text\(([^)]+)\);', r'int valid = (len == 1) || is_valid_text(\1);', s)
if s2 != s:
    open(p, 'w', encoding='utf-8').write(s2)
    print('lundump.c: applied len==1 fix')
else:
    print('lundump.c: no change')
