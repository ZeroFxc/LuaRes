p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Add live variable analysis after NEWTABLE check
old = '''        if(has_newtable){DBG("[UPVAL] block has NEWTABLE at %d, skip\\n",start);pos=end+1;continue;}
        /* 前向数据流分析：第一次出现是读才算外部变量（处理先读后写） */'''
new = '''        if(has_newtable){DBG("[UPVAL] block has NEWTABLE at %d, skip\\n",start);pos=end+1;continue;}
        /* 活跃变量分析：块中写入的寄存器若在块之后被读取，则跳过（IIFE不会把值传回父栈帧） */
        int live_after=0;
        for(int r=0;r<p->maxstacksize && !live_after;r++){
            int written_in_block=0;
            for(int i=start;i<end;i++){
                if(ins_writes_reg(p->code[i],r)){written_in_block=1;break;}
            }
            if(!written_in_block)continue;
            for(int i=end;i<p->sizecode;i++){
                if(ins_reads_reg(p->code[i],r)){live_after=1;break;}
                if(ins_writes_reg(p->code[i],r))break; /* 被重新赋值，不再依赖块中的值 */
            }
        }
        if(live_after){DBG("[UPVAL] block [%d,%d) has live-out register, skip\\n",start,end);pos=end+1;continue;}
        /* 前向数据流分析：第一次出现是读才算外部变量（处理先读后写） */'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('added live-out register analysis')
