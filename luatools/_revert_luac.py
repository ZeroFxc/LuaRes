p = r'E:\LuaRes\luaclib\luac.c'
s = open(p, encoding='utf-8').read()

# Revert to original (no len==1 check)
old = '        int valid = (len == 1) || andlua_is_valid_text(tmp, len);'
new = '        int valid = andlua_is_valid_text(tmp, len);'
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('reverted luac.c LoadString valid check')
