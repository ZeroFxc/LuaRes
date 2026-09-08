p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Fix CONCAT in ins_writes_reg: if A is in [B,C], it's read-before-write, don't count as write
old = '''        case LUAC_OP_UNM:case LUAC_OP_BNOT:case LUAC_OP_NOT:
        case LUAC_OP_LEN:case LUAC_OP_CONCAT:case LUAC_OP_TESTSET:
        case LUAC_OP_FORLOOP:case LUAC_OP_TFORLOOP:
            return A==reg;'''
new = '''        case LUAC_OP_UNM:case LUAC_OP_BNOT:case LUAC_OP_NOT:
        case LUAC_OP_LEN:case LUAC_OP_TESTSET:
        case LUAC_OP_FORLOOP:case LUAC_OP_TFORLOOP:
            return A==reg;
        case LUAC_OP_CONCAT:
            /* CONCAT A B C: R(A)=R(B)....R(C). If A in [B,C], read-before-write, don't count as write */
            if(reg==A && A>=B && A<=C)return 0;
            return A==reg;'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('fixed CONCAT write detection: read-before-write not counted as write')
