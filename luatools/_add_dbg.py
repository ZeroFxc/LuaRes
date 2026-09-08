p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()
old = '''        changed++;
        pos = start + replace_count + 1;'''
new = '''        fprintf(stderr,"[UPVAL] REPLACED block [%d,%d) with CLOSURE+CALL, new code size=%d\\n",start,end,p->sizecode);
        changed++;
        pos = start + replace_count + 1;'''
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('added debug after replace')
