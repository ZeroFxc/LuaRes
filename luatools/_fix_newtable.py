p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Add NEWTABLE check after has_call_ret check
old = '''        if(has_call_ret){DBG("[UPVAL] block has call with ret at %d\\n",start);pos=end+1;continue;}
        /* 前向数据流分析 */'''
new = '''        if(has_call_ret){DBG("[UPVAL] block has call with ret at %d\\n",start);pos=end+1;continue;}
        /* 块中包含 NEWTABLE 时跳过：表创建必须留在父栈帧，IIFE 不会把表引用传回 */
        int has_newtable=0;
        for(int i=start;i<end;i++){
            if((p->code[i]&0x3F)==LUAC_OP_NEWTABLE){has_newtable=1;break;}
        }
        if(has_newtable){DBG("[UPVAL] block has NEWTABLE at %d, skip\\n",start);pos=end+1;continue;}
        /* 前向数据流分析 */'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('added NEWTABLE skip check')
