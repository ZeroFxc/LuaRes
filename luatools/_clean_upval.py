p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Remove the redundant child setup code (from upvalue setup to maxstacksize)
old = '''
        /* upvalue: _ENV at 0, external vars at 1..next */
        child->sizeupvalues = next + 1;
        int nup = next + 1;
        child->upval_name = malloc(sizeof(char*)*nup);
        child->upval_name_len = malloc(sizeof(int)*nup);
        child->upval_instack = malloc(sizeof(unsigned char)*nup);
        child->upval_idx = malloc(sizeof(unsigned char)*nup);
        child->upval_name[0]="_ENV"; child->upval_name_len[0]=4;
        child->upval_instack[0]=0; child->upval_idx[0]=0;
        for (int i=0;i<next;i++) {
            char *nm=malloc(4);
            nm[0]='a'+(obf_rand()%26); nm[1]='a'+(obf_rand()%26);
            nm[2]='a'+(obf_rand()%26); nm[3]='\\0';
            child->upval_name[i+1]=nm; child->upval_name_len[i+1]=3;
            child->upval_instack[i+1]=1; child->upval_idx[i+1]=ext_regs[i];
        }

        /* 子 proto 指令：GETUPVAL + 基本块 + RETURN */
        int total_ins = next + block_len + 1;
        child->code = malloc(sizeof(unsigned int)*total_ins);
        child->sizecode = total_ins;
        for (int i=0;i<next;i++)
            child->code[i] = LUAC_ABC(LUAC_OP_GETUPVAL, ext_regs[i], i+1, 0);
        memcpy(&child->code[next], &p->code[start], sizeof(unsigned int)*block_len);
        child->code[next+block_len] = LUAC_ABC(LUAC_OP_RETURN, 0, 1, 0);

        /* maxstacksize */
        int mr = 2;
        for (int i=start;i<end;i++) {
            int A=(p->code[i]>>6)&0xFF, B=(p->code[i]>>23)&0x1FF, C=(p->code[i]>>14)&0x1FF;
            if (A+1>mr) mr=A+1;
            if (B<256 && B+1>mr) mr=B+1;
            if (C<256 && C+1>mr) mr=C+1;
        }
        for (int i=0;i<next;i++) if (ext_regs[i]+1>mr) mr=ext_regs[i]+1;
        child->maxstacksize = mr;
'''

s = s.replace(old, '\n        /* (minimal child setup done above) */\n')
open(p, 'w', encoding='utf-8').write(s)
print('cleaned up')
