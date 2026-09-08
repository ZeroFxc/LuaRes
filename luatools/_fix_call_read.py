p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

old = '''        case LUAC_OP_CALL:case LUAC_OP_TAILCALL:
            if(B<=1)return 0;
            for(int i=0;i<B-1;i++)if(A+1+i==reg)return 1;
            return 0;'''

new = '''        case LUAC_OP_CALL:case LUAC_OP_TAILCALL:
            if(A==reg)return 1;
            if(B<=1)return 0;
            for(int i=0;i<B-1;i++)if(A+1+i==reg)return 1;
            return 0;'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed ins_reads_reg for CALL/TAILCALL')
