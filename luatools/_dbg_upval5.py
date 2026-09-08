p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Test: set child sizeupvalues = 0
old = '''        child->sizeupvalues = next + 1;  /* +1 for _ENV */'''
new = '''        child->sizeupvalues = 0;  /* DEBUG: no upvalues */'''
s = s.replace(old, new)

# Also don't allocate upvalue arrays
old = '''        /* 分配 upvalue：_ENV at 0, external vars at 1..next */
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

new = '''        /* DEBUG: no upvalues */
        child->upval_name = NULL;
        child->upval_name_len = NULL;
        child->upval_instack = NULL;
        child->upval_idx = NULL;'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('no-upvalues test mode')
