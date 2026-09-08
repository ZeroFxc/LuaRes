p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Change dbg_block_count to output ALL processed blocks (not just first 15)
s = s.replace('if(dbg_block_count<15){', 'if(1){', 1)

# Also add instruction at position 'end' (first instruction after the block)
old = '''            for(int _di=start;_di<end;_di++){
                unsigned int _ins=p->code[_di];
                DBG("  [%d] op=%d A=%d B=%d C=%d\\n",_di,_ins&0x3F,(_ins>>6)&0xFF,(_ins>>23)&0x1FF,(_ins>>14)&0x1FF);
            }'''
new = '''            for(int _di=start;_di<end;_di++){
                unsigned int _ins=p->code[_di];
                DBG("  [%d] op=%d A=%d B=%d C=%d\\n",_di,_ins&0x3F,(_ins>>6)&0xFF,(_ins>>23)&0x1FF,(_ins>>14)&0x1FF);
            }
            if(end<p->sizecode){
                unsigned int _ins=p->code[end];
                DBG("  [%d] NEXT op=%d A=%d B=%d C=%d\\n",end,_ins&0x3F,(_ins>>6)&0xFF,(_ins>>23)&0x1FF,(_ins>>14)&0x1FF);
            }'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('added NEXT instruction output for all processed blocks')
