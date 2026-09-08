p = r'E:\LuaRes\luaclib\cfg_shuffle.c'
s = open(p, encoding='utf-8').read()
old = '''#if CFG_SHUFFLE_DEBUG
    fprintf(stderr, "[cfg_shuffle] sizecode=%d nblocks=%d\\n", p->sizecode, nblocks);
#endif'''
new = '''#if CFG_SHUFFLE_DEBUG
    fprintf(stderr, "[cfg_shuffle] sizecode=%d nblocks=%d\\n", p->sizecode, nblocks);
    for (int _i = 0; _i < p->sizecode; _i++) {
        int _op = p->code[_i] & 0x3F;
        int _a = (p->code[_i] >> 6) & 0xFF;
        int _bx = (p->code[_i] >> 14) & 0x3FFFF;
        fprintf(stderr, "  [%02d] op=%d A=%d bx=%d sbx=%d start=%d\\n", _i, _op, _a, _bx, _bx - 131072, is_start[_i]);
    }
#endif'''
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('done')
