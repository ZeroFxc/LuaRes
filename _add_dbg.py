p = r'E:\LuaRes\luaclib\cfg_shuffle.c'
s = open(p, encoding='utf-8').read()
old = '''    /* === 步骤3: 确定每个块的后继 === */
    for (int b = 0; b < nblocks; b++) {
        int last = blocks[b].end - 1;
        int op = p->code[last] & 0x3F;

        if (op == 30) {  /* JMP */'''
new = '''    /* === 步骤3: 确定每个块的后继 === */
    for (int b = 0; b < nblocks; b++) {
        int last = blocks[b].end - 1;
        int op = p->code[last] & 0x3F;
#if CFG_SHUFFLE_DEBUG
        fprintf(stderr, "  block[%d] last_idx=%d op=%d\\n", b, last, op);
#endif

        if (op == 30) {  /* JMP */'''
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('done')
