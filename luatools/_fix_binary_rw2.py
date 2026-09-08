p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# The binary ops are in the same case as MOVE/LOADK/etc. Need to split them out.
# Current: all return A==reg in one big case
# We need: binary ops with A==B or A==C return 0 (read-before-write)

old = '''        case LUAC_OP_MOVE:case LUAC_OP_LOADK:case LUAC_OP_LOADKX:
        case LUAC_OP_LOADBOOL:case LUAC_OP_GETUPVAL:case LUAC_OP_GETTABUP:
        case LUAC_OP_GETTABLE:case LUAC_OP_NEWTABLE:
        case LUAC_OP_ADD:case LUAC_OP_SUB:case LUAC_OP_MUL:
        case LUAC_OP_MOD:case LUAC_OP_POW:case LUAC_OP_DIV:
        case LUAC_OP_IDIV:case LUAC_OP_BAND:case LUAC_OP_BOR:
        case LUAC_OP_BXOR:case LUAC_OP_SHL:case LUAC_OP_SHR:
        case LUAC_OP_UNM:case LUAC_OP_BNOT:case LUAC_OP_NOT:
        case LUAC_OP_LEN:case LUAC_OP_TESTSET:
        case LUAC_OP_FORLOOP:case LUAC_OP_TFORLOOP:
            return A==reg;'''
new = '''        case LUAC_OP_MOVE:case LUAC_OP_LOADK:case LUAC_OP_LOADKX:
        case LUAC_OP_LOADBOOL:case LUAC_OP_GETUPVAL:case LUAC_OP_GETTABUP:
        case LUAC_OP_GETTABLE:case LUAC_OP_NEWTABLE:
        case LUAC_OP_UNM:case LUAC_OP_BNOT:case LUAC_OP_NOT:
        case LUAC_OP_LEN:case LUAC_OP_TESTSET:
        case LUAC_OP_FORLOOP:case LUAC_OP_TFORLOOP:
            return A==reg;
        case LUAC_OP_ADD:case LUAC_OP_SUB:case LUAC_OP_MUL:
        case LUAC_OP_MOD:case LUAC_OP_POW:case LUAC_OP_DIV:
        case LUAC_OP_IDIV:case LUAC_OP_BAND:case LUAC_OP_BOR:
        case LUAC_OP_BXOR:case LUAC_OP_SHL:case LUAC_OP_SHR:
            /* If A is also a source (A==B or A==C), read-before-write, don't count as write */
            if(reg==A && ((B<256&&B==A)||(C<256&&C==A)))return 0;
            return A==reg;'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('fixed ins_writes_reg: split binary ops from big case branch')
