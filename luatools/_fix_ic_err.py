p = r'E:\LuaRes\luaclib\integrity_check.c'
s = open(p, encoding='utf-8').read()
old = '        "  while true do end\\n"\n        "end\\n",'
new = '        "  (nil)()\\n"\n        "end\\n",'
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('done')
