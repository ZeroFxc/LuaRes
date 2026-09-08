p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

old = '''        if(end-start<2){DBG("[UPVAL] block too short at %d len=%d\\n",pos,end-start);pos=end+1;continue;}
        int has_call_ret=0;
        for(int i=start;i<end;i++){
            int op=p->code[i]&0x3F;
            if((op==LUAC_OP_CALL||op==LUAC_OP_TAILCALL)&&((p->code[end]>>14)&0x1FF)>1){
                has_call_ret=1;break;
            }
        }
        if(has_call_ret){DBG("[UPVAL] block has call with ret at %d\\n",start);pos=end+1;continue;}'''

new = '''        if(end-start<2){DBG("[UPVAL] block too short at %d len=%d\\n",pos,end-start);pos=end+1;continue;}
        /* 块必须以 CALL(C<=1) 或 TAILCALL 结尾，否则截断到上一个 CALL */
        while(end-start>=2){
            int last_op=p->code[end-1]&0x3F;
            int last_C=(p->code[end-1]>>14)&0x1FF;
            if((last_op==LUAC_OP_CALL||last_op==LUAC_OP_TAILCALL)&&last_C<=1)break;
            end--;
        }
        if(end-start<2){DBG("[UPVAL] block truncated too short at %d\\n",start);pos=end+1;continue;}
        int has_call_ret=0;
        for(int i=start;i<end;i++){
            int op=p->code[i]&0x3F;
            if((op==LUAC_OP_CALL||op==LUAC_OP_TAILCALL)&&((p->code[i]>>14)&0x1FF)>1){
                has_call_ret=1;break;
            }
        }
        if(has_call_ret){DBG("[UPVAL] block has call with ret at %d\\n",start);pos=end+1;continue;}'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed block ending: must end with CALL(C<=1)')
