p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Add ext_regs dump after ext_count log
old = '''        DBG("[UPVAL] block [%d,%d) len=%d maxstack=%d ext_count=%d\\n",start,end,end-start,p->maxstacksize,next);'''
new = '''        DBG("[UPVAL] block [%d,%d) len=%d maxstack=%d ext_count=%d",start,end,end-start,p->maxstacksize,next);
        for(int _ei=0;_ei<next;_ei++)DBG(" R%d",ext_regs[_ei]);
        DBG("\\n");'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('added ext_regs dump')
