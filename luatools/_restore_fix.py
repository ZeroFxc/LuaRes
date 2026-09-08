p = r'E:\LuaRes\luaclib\luac.c'
s = open(p, encoding='utf-8').read()

# Restore proper fix
old = '        int valid = 1; /* DEBUG: always decrypt when encrypted */'
new = '        int valid = (len == 1) || andlua_is_valid_text(tmp, len);'
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('restored proper fix')
