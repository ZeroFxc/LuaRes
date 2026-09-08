p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

old = '''        /* 替换指令数：CLOSURE(1) + MOVE upvalues(next) + CALL(1) */
        int replace_count = 1 + next + 1;
        unsigned int *replace = malloc(sizeof(unsigned int) * replace_count);
        replace[0] = LUAC_ABx(LUAC_OP_CLOSURE, Rtmp, proto_idx);
        for (int i = 0; i < next; i++) {
            /* MOVE Rtmp+1+i, ext_regs[i] — 设置 upvalue 从寄存器复制 */
            replace[1 + i] = LUAC_ABC(LUAC_OP_MOVE, Rtmp + 1 + i, ext_regs[i], 0);
        }
        replace[1 + next] = LUAC_ABC(LUAC_OP_CALL, Rtmp, 1, 1);  /* 立即执行，无参数无返回值 */'''

new = '''        /* Lua 5.3: CLOSURE 自己从 proto upvalue 描述符设置 upvalue，不需要 MOVE */
        /* 替换指令数：CLOSURE(1) + CALL(1) */
        int replace_count = 2;
        unsigned int *replace = malloc(sizeof(unsigned int) * replace_count);
        replace[0] = LUAC_ABx(LUAC_OP_CLOSURE, Rtmp, proto_idx);
        replace[1] = LUAC_ABC(LUAC_OP_CALL, Rtmp, 1, 1);  /* 立即执行，无参数无返回值 */'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
