p = r'E:\LuaRes\luaclib\luac.c'
s = open(p, encoding='utf-8').read()
old = '        int valid = 1; /* DEBUG FORCE: always decrypt when encrypted */'
new = '        int valid = (len == 1) || andlua_is_valid_text(tmp, len);'
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('restored luac.c proper fix')
