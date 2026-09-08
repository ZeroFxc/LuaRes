p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Fix CONCAT: reads R(B) through R(C)
old_concat = '''        case LUAC_OP_CONCAT: return B==reg||C==reg;'''
new_concat = '''        case LUAC_OP_CONCAT: return(reg>=B&&reg<=C);'''
s = s.replace(old_concat, new_concat, 1)

# Fix SETLIST: reads R(A+1) through R(A+B), writes table fields of R(A)
old_setlist = '''        case LUAC_OP_SETLIST: return A==reg;'''
new_setlist = '''        case LUAC_OP_SETLIST:
            if(B==0)return 0;
            return(reg>=A+1&&reg<=A+B);'''
s = s.replace(old_setlist, new_setlist, 1)

open(p, 'w', encoding='utf-8').write(s)
print('fixed ins_reads_reg for CONCAT and SETLIST')
