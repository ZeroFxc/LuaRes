p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

old = '''        int defined[256]={0};
        for(int i=start;i<end;i++)
            for(int r=0;r<256;r++)
                if(ins_writes_reg(p->code[i],r))defined[r]=1;
        int ext_regs[32],next=0;
        for(int r=0;r<p->maxstacksize;r++){
            if(defined[r])continue;
            for(int i=start;i<end;i++)
                if(ins_reads_reg(p->code[i],r)){
                    if(next<32)ext_regs[next++]=r;
                    break;
                }
        }'''

new = '''        /* 前向数据流分析：第一次出现是读才算外部变量（处理先读后写） */
        int ext_regs[32],next=0;
        for(int r=0;r<p->maxstacksize;r++){
            int first_read=-1,first_write=-1;
            for(int i=start;i<end;i++){
                if(first_read<0 && ins_reads_reg(p->code[i],r))first_read=i;
                if(first_write<0 && ins_writes_reg(p->code[i],r))first_write=i;
            }
            if(first_read>=0 && (first_write<0 || first_read<first_write)){
                if(next<32)ext_regs[next++]=r;
            }
        }'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed external variable analysis with forward data flow')
