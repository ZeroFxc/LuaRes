p = r'E:\LuaRes\luaclib\luac.c'
s = open(p, encoding='utf-8').read()

# Change to always decrypt when encrypted
old = '        int valid = (len == 1) || andlua_is_valid_text(tmp, len);'
new = '        int valid = 1; /* DEBUG: always decrypt when encrypted */'
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('changed to always decrypt')
