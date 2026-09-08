p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Replace CLOSURE+CALL with just a NOP to isolate the issue
old = '''        /* 替换指令数：CLOSURE(1) + CALL(1) */
        int replace_count = 2;
        unsigned int *replace = malloc(sizeof(unsigned int) * replace_count);
        replace[0] = LUAC_ABx(LUAC_OP_CLOSURE, Rtmp, proto_idx);
        replace[1] = LUAC_ABC(LUAC_OP_CALL, Rtmp, 1, 1);  /* 立即执行，无参数无返回值 */'''

new = '''        /* DEBUG: replace with NOP only */
        int replace_count = 1;
        unsigned int *replace = malloc(sizeof(unsigned int) * replace_count);
        replace[0] = LUAC_ABC(LUAC_OP_MOVE, 0, 0, 0);  /* NOP */
        (void)proto_idx; (void)Rtmp;'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('NOP-only replacement test')
