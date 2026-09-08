p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Fix ins_writes_reg for binary ops where A is also a source (A==B or A==C)
old = '''        case LUAC_OP_ADD:case LUAC_OP_SUB:case LUAC_OP_MUL:
        case LUAC_OP_MOD:case LUAC_OP_POW:case LUAC_OP_DIV:
        case LUAC_OP_IDIV:case LUAC_OP_BAND:case LUAC_OP_BOR:
        case LUAC_OP_BXOR:case LUAC_OP_SHL:case LUAC_OP_SHR:
            return A==reg;'''
new = '''        case LUAC_OP_ADD:case LUAC_OP_SUB:case LUAC_OP_MUL:
        case LUAC_OP_MOD:case LUAC_OP_POW:case LUAC_OP_DIV:
        case LUAC_OP_IDIV:case LUAC_OP_BAND:case LUAC_OP_BOR:
        case LUAC_OP_BXOR:case LUAC_OP_SHL:case LUAC_OP_SHR:
            /* If A is also a source (A==B or A==C), read-before-write, don't count as write */
            if(reg==A && ((B<256&&B==A)||(C<256&&C==A)))return 0;
            return A==reg;'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('fixed ins_writes_reg for binary ops with A==B or A==C')
