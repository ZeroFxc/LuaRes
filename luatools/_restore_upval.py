p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Restore full replacement code with correct JMP adjustment
old = '''        /* 在原位置替换 */
        int delta = replace_count - block_len;
        if (delta > 0) {
            p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + delta));
            memmove(&p->code[start + replace_count], &p->code[end],
                    sizeof(unsigned int) * (p->sizecode - end));
        } else if (delta < 0) {
            memmove(&p->code[start + replace_count], &p->code[end],
                    sizeof(unsigned int) * (p->sizecode - end));
        }
        memcpy(&p->code[start], replace, sizeof(unsigned int) * replace_count);
        p->sizecode += delta;
        free(replace);

        /* DEBUG: skip JMP adjustment */
        changed++;
        pos = start + replace_count + 1;'''

new = '''        /* 在原位置替换 */
        int delta = replace_count - block_len;
        if (delta > 0) {
            p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + delta));
            memmove(&p->code[start + replace_count], &p->code[end],
                    sizeof(unsigned int) * (p->sizecode - end));
        } else if (delta < 0) {
            memmove(&p->code[start + replace_count], &p->code[end],
                    sizeof(unsigned int) * (p->sizecode - end));
        }
        memcpy(&p->code[start], replace, sizeof(unsigned int) * replace_count);
        p->sizecode += delta;
        free(replace);

        /* 正确修正替换型 JMP 偏移 */
        if (delta != 0) {
            int old_end = start + block_len;
            int new_end = start + replace_count;
            for (int i = 0; i < p->sizecode; i++) {
                int op = p->code[i] & 0x3F;
                if (op != LUAC_OP_JMP && op != LUAC_OP_FORLOOP &&
                    op != LUAC_OP_FORPREP && op != LUAC_OP_TFORLOOP) continue;
                /* JMP inside replaced region shouldn't exist (basic block) */
                if (i >= start && i < new_end) continue;
                int old_i = (i < start) ? i : i - delta;
                int sbx = (int)(p->code[i] >> 14) - 131071;
                int old_target = old_i + sbx + 1;
                int new_target;
                if (old_target <= start) new_target = old_target;
                else if (old_target >= old_end) new_target = old_target + delta;
                else continue;  /* target inside replaced region, shouldn't exist */
                int new_sbx = new_target - i - 1;
                p->code[i] = (p->code[i] & 0x3FFF) | ((unsigned int)(new_sbx + 131071) << 14);
            }
        }

        changed++;
        pos = start + replace_count + 1;'''

s = s.replace(old, new)

# Restore CLOSURE+CALL replacement
old = '''        /* DEBUG: CLOSURE only, no CALL */
        int replace_count = 1;
        unsigned int *replace = malloc(sizeof(unsigned int) * replace_count);
        replace[0] = LUAC_ABx(LUAC_OP_CLOSURE, Rtmp, proto_idx);'''
new = '''        /* 替换指令数：CLOSURE(1) + CALL(1) */
        int replace_count = 2;
        unsigned int *replace = malloc(sizeof(unsigned int) * replace_count);
        replace[0] = LUAC_ABx(LUAC_OP_CLOSURE, Rtmp, proto_idx);
        replace[1] = LUAC_ABC(LUAC_OP_CALL, Rtmp, 1, 1);  /* 立即执行，无参数无返回值 */'''
s = s.replace(old, new)

# Restore full child code (GETUPVAL + block + RETURN)
old = '''        /* DEBUG: minimal proto - just RETURN */
        int total_ins = 1;
        child->code = malloc(sizeof(unsigned int) * total_ins);
        child->sizecode = total_ins;
        child->code[0] = LUAC_ABC(LUAC_OP_RETURN, 0, 1, 0);
        (void)load_count; (void)block_len; (void)ext_regs;'''
new = '''        /* 新 proto 指令：GETUPVAL * next + 基本块 + RETURN */
        int total_ins = load_count + block_len + 1;
        child->code = malloc(sizeof(unsigned int) * total_ins);
        child->sizecode = total_ins;

        /* GETUPVAL 加载外部变量到原寄存器（upvalue index = i+1, 0 is _ENV） */
        for (int i = 0; i < next; i++) {
            child->code[i] = LUAC_ABC(LUAC_OP_GETUPVAL, ext_regs[i], i + 1, 0);
        }
        /* 复制基本块指令 */
        memcpy(&child->code[load_count], &p->code[start],
               sizeof(unsigned int) * block_len);
        /* RETURN */
        child->code[load_count + block_len] = LUAC_ABC(LUAC_OP_RETURN, 0, 1, 0);'''
s = s.replace(old, new)

# Restore upvalues
old = '''        /* DEBUG: no upvalues */
        child->upval_name = NULL;
        child->upval_name_len = NULL;
        child->upval_instack = NULL;
        child->upval_idx = NULL;'''
new = '''        /* 分配 upvalue：_ENV at 0, external vars at 1..next */
        int nup = next + 1;
        child->upval_name = malloc(sizeof(char*) * nup);
        child->upval_name_len = malloc(sizeof(int) * nup);
        child->upval_instack = malloc(sizeof(unsigned char) * nup);
        child->upval_idx = malloc(sizeof(unsigned char) * nup);
        /* upvalue 0: _ENV, 引用父函数的 upvalue 0 */
        child->upval_name[0] = "_ENV";
        child->upval_name_len[0] = 4;
        child->upval_instack[0] = 0;  /* 从父 upvalue 引用 */
        child->upval_idx[0] = 0;      /* 父 upvalue 0 */
        /* upvalue 1..next: external variables from parent registers */
        for (int i = 0; i < next; i++) {
            char *name = malloc(4);
            name[0] = 'a' + (obf_rand() % 26);
            name[1] = 'a' + (obf_rand() % 26);
            name[2] = 'a' + (obf_rand() % 26);
            name[3] = '\\0';
            child->upval_name[i + 1] = name;
            child->upval_name_len[i + 1] = 3;
            child->upval_instack[i + 1] = 1;  /* 从寄存器复制 */
            child->upval_idx[i + 1] = ext_regs[i];  /* 源寄存器 */
        }'''
s = s.replace(old, new)

# Restore sizeupvalues
old = '        child->sizeupvalues = 0;  /* DEBUG: no upvalues */'
new = '        child->sizeupvalues = next + 1;  /* +1 for _ENV */'
s = s.replace(old, new)

# Restore constants
old = '        /* DEBUG: skip constant copying */\n        if (0 && p->sizek > 0) {'
new = '        /* 复制父函数常量池到子 proto（基本块指令可能引用常量） */\n        if (p->sizek > 0) {'
s = s.replace(old, new)

open(p, 'w', encoding='utf-8').write(s)
print('full module restored with correct JMP adjustment')
