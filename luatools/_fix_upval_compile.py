p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Replace the minimal child creation with obf_compile_subproto
old = '''        /* 创建子 proto */
        luac_Proto *child = new_proto();
        int block_len = end - start;

        /* DEBUG: minimal child - just RETURN, 0 upvalues, 0 constants */
        child->code = malloc(sizeof(unsigned int));
        child->sizecode = 1;
        child->code[0] = LUAC_ABC(LUAC_OP_RETURN, 0, 1, 0);
        child->sizeupvalues = 0;
        child->maxstacksize = 2;
        (void)ext_regs; (void)next;

        /* (minimal child setup done above) */'''

new = '''        /* 创建子 proto - use obf_compile_subproto for valid proto */
        luac_Proto *child = NULL;
        int block_len = end - start;
        if (obf_compile_subproto(L, "return", &child) != 0 || !child) {
            pos = end + 1; continue;
        }
        (void)ext_regs; (void)next;'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('using obf_compile_subproto')
