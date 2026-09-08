p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Add detailed dataflow log after ext_regs calculation
old = '''        DBG("[UPVAL] block [%d,%d) len=%d maxstack=%d ext_count=%d",start,end,end-start,p->maxstacksize,next);
        for(int _ei=0;_ei<next;_ei++)DBG(" R%d",ext_regs[_ei]);
        DBG("\\n");'''
new = '''        DBG("[UPVAL] block [%d,%d) len=%d maxstack=%d ext_count=%d",start,end,end-start,p->maxstacksize,next);
        for(int _ei=0;_ei<next;_ei++)DBG(" R%d",ext_regs[_ei]);
        DBG("\\n");
        /* Dump first 3 blocks instructions for debugging */
        static int dbg_block_count=0;
        if(dbg_block_count<3){
            dbg_block_count++;
            DBG("[DBG_BLOCK %d] instructions:\\n",dbg_block_count);
            for(int _di=start;_di<end;_di++){
                unsigned int _ins=p->code[_di];
                DBG("  [%d] op=%d A=%d B=%d C=%d\\n",_di,_ins&0x3F,(_ins>>6)&0xFF,(_ins>>23)&0x1FF,(_ins>>14)&0x1FF);
            }
        }'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('added first 3 blocks detailed dump')
