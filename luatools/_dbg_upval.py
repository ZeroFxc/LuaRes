p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Temporarily replace the child code creation with minimal code (just RETURN)
# to isolate whether the issue is proto creation or instruction content
old = '''        /* 新 proto 指令：GETUPVAL * next + 基本块 + RETURN */
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

new = '''        /* DEBUG: minimal proto - just RETURN */
        int total_ins = 1;
        child->code = malloc(sizeof(unsigned int) * total_ins);
        child->sizecode = total_ins;
        child->code[0] = LUAC_ABC(LUAC_OP_RETURN, 0, 1, 0);
        (void)load_count; (void)block_len; (void)ext_regs;'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('minimal test mode')
