p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# 1. Enable debug
s = s.replace('#define UPVAL_DEBUG 0', '#define UPVAL_DEBUG 1')

# 2. Add more detailed debug in fix_jumps_replace
old_fix = '''static void fix_jumps_replace(unsigned int *code,int code_len,
                               int start,int old_len,int new_len){
    int delta=new_len-old_len;
    if(delta==0)return;
    int old_end=start+old_len,new_end=start+new_len;
    for(int i=0;i<code_len;i++){
        int op=code[i]&0x3F;
        if(op!=LUAC_OP_JMP&&op!=LUAC_OP_FORLOOP&&
           op!=LUAC_OP_FORPREP&&op!=LUAC_OP_TFORLOOP)continue;
        if(i>=start&&i<new_end)continue;
        int old_i=(i<start)?i:i-delta;
        int sbx=(int)(code[i]>>14)-131071;
        int old_target=old_i+sbx+1;
        int new_target;
        if(old_target<=start)new_target=old_target;
        else if(old_target>=old_end)new_target=old_target+delta;
        else continue;
        int new_sbx=new_target-i-1;
        code[i]=(code[i]&0x3FFF)|((unsigned int)(new_sbx+131071)<<14);
    }
}'''

new_fix = '''static void fix_jumps_replace(unsigned int *code,int code_len,
                               int start,int old_len,int new_len){
    int delta=new_len-old_len;
    if(delta==0)return;
    int old_end=start+old_len,new_end=start+new_len;
    DBG("[FIX] start=%d old_len=%d new_len=%d delta=%d old_end=%d new_end=%d code_len=%d\\n",
        start,old_len,new_len,delta,old_end,new_end,code_len);
    for(int i=0;i<code_len;i++){
        int op=code[i]&0x3F;
        if(op!=LUAC_OP_JMP&&op!=LUAC_OP_FORLOOP&&
           op!=LUAC_OP_FORPREP&&op!=LUAC_OP_TFORLOOP)continue;
        if(i>=start&&i<new_end){DBG("[FIX] skip JMP at %d (inside replace region)\\n",i);continue;}
        int old_i=(i<start)?i:i-delta;
        int sbx=(int)(code[i]>>14)-131071;
        int old_target=old_i+sbx+1;
        int new_target;
        if(old_target<=start)new_target=old_target;
        else if(old_target>=old_end)new_target=old_target+delta;
        else {DBG("[FIX] SKIP JMP at %d op=%d old_i=%d sbx=%d old_target=%d (target inside region [%d,%d))\\n",
            i,op,old_i,sbx,old_target,start,old_end);continue;}
        int new_sbx=new_target-i-1;
        if(new_sbx!=sbx){
            DBG("[FIX] JMP at %d op=%d: old_i=%d sbx=%d->%d target=%d->%d\\n",
                i,op,old_i,sbx,new_sbx,old_target,new_target);
        }
        code[i]=(code[i]&0x3FFF)|((unsigned int)(new_sbx+131071)<<14);
    }
}'''

s = s.replace(old_fix, new_fix)

# 3. Add debug before/after replace, and dump child proto
old_replace = '''        int proto_idx=add_sub_proto(p,child);
        int old_max=p->maxstacksize;
        if(old_max+1>250){pos=end+1;continue;}
        int Rtmp=old_max;
        obf_ensure_stack(p,Rtmp+1+child->maxstacksize);

        int replace_count=2;
        unsigned int *replace=malloc(sizeof(unsigned int)*2);
        replace[0]=LUAC_ABx(LUAC_OP_CLOSURE,Rtmp,proto_idx);
        replace[1]=LUAC_ABC(LUAC_OP_CALL,Rtmp,1,1);

        int delta=replace_count-block_len;
        if(delta>0){
            p->code=realloc(p->code,sizeof(unsigned int)*(p->sizecode+delta));
            memmove(&p->code[start+replace_count],&p->code[end],
                    sizeof(unsigned int)*(p->sizecode-end));
        }else if(delta<0){
            memmove(&p->code[start+replace_count],&p->code[end],
                    sizeof(unsigned int)*(p->sizecode-end));
        }
        memcpy(&p->code[start],replace,sizeof(unsigned int)*replace_count);
        p->sizecode+=delta;
        free(replace);

        fix_jumps_replace(p->code,p->sizecode,start,block_len,replace_count);

        changed++;
        pos=start+replace_count+1;'''

new_replace = '''        int proto_idx=add_sub_proto(p,child);
        int old_max=p->maxstacksize;
        if(old_max+1>250){DBG("[UPVAL] skip: old_max+1>250 at %d\\n",start);pos=end+1;continue;}
        int Rtmp=old_max;
        obf_ensure_stack(p,Rtmp+1+child->maxstacksize);
        DBG("[UPVAL] proto_idx=%d Rtmp=%d child_maxstack=%d parent_maxstack=%d->%d\\n",
            proto_idx,Rtmp,child->maxstacksize,old_max,p->maxstacksize);

        /* dump block before */
        DBG("[UPVAL] BLOCK BEFORE at [%d,%d):\\n",start,end);
        for(int di=start;di<end;di++){
            int dop=p->code[di]&0x3F,dA=(p->code[di]>>6)&0xFF,dB=(p->code[di]>>23)&0x1FF,dC=(p->code[di]>>14)&0x1FF;
            DBG("  [%d] op=%d A=%d B=%d C=%d\\n",di,dop,dA,dB,dC);
        }
        /* dump child proto */
        DBG("[UPVAL] CHILD proto: sizecode=%d maxstack=%d sizek=%d nup=%d\\n",
            child->sizecode,child->maxstacksize,child->sizek,child->sizeupvalues);
        for(int di=0;di<child->sizecode;di++){
            int dop=child->code[di]&0x3F,dA=(child->code[di]>>6)&0xFF,dB=(child->code[di]>>23)&0x1FF,dC=(child->code[di]>>14)&0x1FF;
            DBG("  child[%d] op=%d A=%d B=%d C=%d\\n",di,dop,dA,dB,dC);
        }
        for(int ui=0;ui<child->sizeupvalues;ui++){
            DBG("  child upval[%d]: instack=%d idx=%d\\n",ui,child->upval_instack[ui],child->upval_idx[ui]);
        }

        int replace_count=2;
        unsigned int *replace=malloc(sizeof(unsigned int)*2);
        replace[0]=LUAC_ABx(LUAC_OP_CLOSURE,Rtmp,proto_idx);
        replace[1]=LUAC_ABC(LUAC_OP_CALL,Rtmp,1,1);

        int delta=replace_count-block_len;
        if(delta>0){
            p->code=realloc(p->code,sizeof(unsigned int)*(p->sizecode+delta));
            memmove(&p->code[start+replace_count],&p->code[end],
                    sizeof(unsigned int)*(p->sizecode-end));
        }else if(delta<0){
            memmove(&p->code[start+replace_count],&p->code[end],
                    sizeof(unsigned int)*(p->sizecode-end));
        }
        memcpy(&p->code[start],replace,sizeof(unsigned int)*replace_count);
        p->sizecode+=delta;
        free(replace);

        fix_jumps_replace(p->code,p->sizecode,start,block_len,replace_count);

        /* dump code after replace (first 30 instructions) */
        DBG("[UPVAL] AFTER replace, sizecode=%d, first 30 ins:\\n",p->sizecode);
        for(int di=0;di<(p->sizecode<30?p->sizecode:30);di++){
            int dop=p->code[di]&0x3F,dA=(p->code[di]>>6)&0xFF,dB=(p->code[di]>>23)&0x1FF,dC=(p->code[di]>>14)&0x1FF;
            int dsbx=((p->code[di]>>14)&0x3FFFF)-131071;
            if(dop==LUAC_OP_JMP||dop==LUAC_OP_FORLOOP||dop==LUAC_OP_FORPREP)
                DBG("  [%d] op=%d A=%d sbx=%d\\n",di,dop,dA,dsbx);
            else
                DBG("  [%d] op=%d A=%d B=%d C=%d\\n",di,dop,dA,dB,dC);
        }

        changed++;
        pos=start+replace_count+1;
        DBG("[UPVAL] block done, changed=%d, next pos=%d\\n",changed,pos);'''

s = s.replace(old_replace, new_replace)

open(p, 'w', encoding='utf-8').write(s)
print('debug logging added to upvalue_promote.c')
