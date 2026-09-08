p = r'E:\LuaRes\luasafe\lundump.c'
s = open(p, encoding='utf-8').read()
old = '  for (i = 0; i < n; i++) {\n    TValue *o = &f->k[i];\n    int t = LoadByte(S);'
new = '  for (i = 0; i < n; i++) {\n    TValue *o = &f->k[i];\n    int t = LoadByte(S);\n    if (i >= 80 && i <= 95) fprintf(stderr, "[LUNDUMP] k[%d] tag=%d\\n", i, t);'
if old in s:
    s = s.replace(old, new)
    open(p, 'w', encoding='utf-8').write(s)
    print('debug added')
else:
    print('NOT FOUND')
