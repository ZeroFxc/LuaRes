p = r'E:\LuaRes\luaclib\block_clone.c'
s = open(p, encoding='utf-8').read()

# Fix 1: find_blocks - split after FORLOOP, FORPREP, TFORLOOP (they are block terminators)
old1 = """        if (op == LUAC_OP_JMP || op == LUAC_OP_RETURN || op == LUAC_OP_TAILCALL) {
            if (i + 1 < n) is_start[i + 1] = 1;
        }"""
new1 = """        if (op == LUAC_OP_JMP || op == LUAC_OP_RETURN || op == LUAC_OP_TAILCALL ||
            op == LUAC_OP_FORLOOP || op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) {
            if (i + 1 < n) is_start[i + 1] = 1;
        }"""
s = s.replace(old1, new1, 1)

# Fix 2: is_cloneable - reject all jump/conditional instructions
old2 = """        /* Block terminators */
        if (op == LUAC_OP_JMP || op == LUAC_OP_RETURN || op == LUAC_OP_TAILCALL) return 0;"""
new2 = """        /* Block terminators / jump instructions */
        if (op == LUAC_OP_JMP || op == LUAC_OP_RETURN || op == LUAC_OP_TAILCALL) return 0;
        if (op == LUAC_OP_FORLOOP || op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) return 0;
        /* Conditional ops (always followed by JMP) */
        if (op == LUAC_OP_EQ || op == LUAC_OP_LT || op == LUAC_OP_LE) return 0;
        if (op == LUAC_OP_TEST || op == LUAC_OP_TESTSET) return 0;"""
s = s.replace(old2, new2, 1)

open(p, 'w', encoding='utf-8').write(s)
print('Fixed block identification and cloneable checks')
