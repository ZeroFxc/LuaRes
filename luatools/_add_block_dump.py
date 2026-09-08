p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Add detailed block instruction dump after BLOCK BEFORE
old = '''        DBG("[UPVAL] BLOCK BEFORE at [%d,%d):\\n",start,end);'''
new = '''        DBG("[UPVAL] BLOCK BEFORE at [%d,%d):\\n",start,end);
        for(int _di=start;_di<end;_di++){
            unsigned int _ins=p->code[_di];
            DBG("  [%d] op=%d A=%d B=%d C=%d\\n",_di,_ins&0x3F,(_ins>>6)&0xFF,(_ins>>23)&0x1FF,(_ins>>14)&0x1FF);
        }'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('added detailed block instruction dump')
