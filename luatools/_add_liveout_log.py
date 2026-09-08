p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Add logging to live-out analysis
old = '''        if(live_after){DBG("[UPVAL] block [%d,%d) has live-out register, skip\\n",start,end);pos=end+1;continue;}'''
new = '''        if(live_after){
            DBG("[UPVAL] block [%d,%d) has live-out register, skip\\n",start,end);
            /* Find which register is live-out */
            for(int r=0;r<p->maxstacksize;r++){
                int written_in_block=0;
                for(int i=start;i<end;i++){
                    if(ins_writes_reg(p->code[i],r)){written_in_block=1;break;}
                }
                if(!written_in_block)continue;
                for(int i=end;i<p->sizecode;i++){
                    if(ins_reads_reg(p->code[i],r)){DBG("  live-out reg R%d first read at pos %d (op=%d)\\n",r,i,p->code[i]&0x3F);break;}
                    if(ins_writes_reg(p->code[i],r)){DBG("  reg R%d re-written at pos %d (op=%d) before read\\n",r,i,p->code[i]&0x3F);break;}
                }
            }
            pos=end+1;continue;
        }'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('added live-out register logging')
