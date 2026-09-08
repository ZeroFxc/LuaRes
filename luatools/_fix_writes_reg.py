p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Fix SELF: writes R(A) and R(A+1)
old_self = '''        case LUAC_OP_LOADNIL:
            for(int i=0;i<=B;i++)if(A+i==reg)return 1;
            return 0;'''
new_self = '''        case LUAC_OP_SELF: return A==reg||A+1==reg;
        case LUAC_OP_LOADNIL:
            for(int i=0;i<=B;i++)if(A+i==reg)return 1;
            return 0;'''
s = s.replace(old_self, new_self, 1)

# Fix VARARG: writes R(A) through R(A+B-2)
old_vararg = '''        case LUAC_OP_FORLOOP:case LUAC_OP_TFORLOOP:case LUAC_OP_VARARG:
            return A==reg;'''
new_vararg = '''        case LUAC_OP_FORLOOP:case LUAC_OP_TFORLOOP:
            return A==reg;
        case LUAC_OP_VARARG:
            if(B<=1)return 0;
            for(int i=0;i<B-1;i++)if(A+i==reg)return 1;
            return 0;'''
s = s.replace(old_vararg, new_vararg, 1)

open(p, 'w', encoding='utf-8').write(s)
print('fixed ins_writes_reg for SELF and VARARG')
