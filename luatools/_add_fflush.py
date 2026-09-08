p = r'E:\LuaRes\luasafe\lvm.c'
s = open(p, encoding='utf-8').read()
old = '(rb->tt_ == 4 || rb->tt_ == 20 || rb->tt_ == 68) ? getstr(tsvalue(rb)) : "(non-str)");'
new = old + '\n        fflush(stderr);'
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('done')
