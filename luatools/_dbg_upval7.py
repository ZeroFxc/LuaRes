p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Test: CLOSURE only, no CALL
old = '''        /* DEBUG: replace with NOP only */
        int replace_count = 1;
        unsigned int *replace = malloc(sizeof(unsigned int) * replace_count);
        replace[0] = LUAC_ABC(LUAC_OP_MOVE, 0, 0, 0);  /* NOP */
        (void)proto_idx; (void)Rtmp;'''

new = '''        /* DEBUG: CLOSURE only, no CALL */
        int replace_count = 1;
        unsigned int *replace = malloc(sizeof(unsigned int) * replace_count);
        replace[0] = LUAC_ABx(LUAC_OP_CLOSURE, Rtmp, proto_idx);'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('CLOSURE-only test')
