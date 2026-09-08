p = r'E:\LuaRes\luaclib\const_hide.c'
s = open(p, encoding='utf-8').read()
old = '''    /* each hidden string can expand to up to 20 instructions (SETTABUP with both key+val hidden: 2*8+1=17) */
    int max_new = p->sizecode + str_count * 20 + 64;'''
new = '''    /* each instruction can expand to up to 22 instructions (SETTABUP with both key+val hidden: 2*10+2=22) */
    int max_new = p->sizecode * 25 + 64;'''
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
