p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Add ins_modifies_reg function before ins_writes_reg
old = '''static int ins_writes_reg(unsigned int ins, int reg) {'''
new = '''/* 活跃变量分析用：是否修改了寄存器的值（既读又写也算修改） */
static int ins_modifies_reg(unsigned int ins, int reg) {
    int op=ins&0x3F,A=(ins>>6)&0xFF,B=(ins>>23)&0x1FF,C=(ins>>14)&0x1FF;
    switch(op){
        case LUAC_OP_MOVE:case LUAC_OP_LOADK:case LUAC_OP_LOADKX:
        case LUAC_OP_LOADBOOL:case LUAC_OP_GETUPVAL:case LUAC_OP_GETTABUP:
        case LUAC_OP_GETTABLE:case LUAC_OP_NEWTABLE:
        case LUAC_OP_ADD:case LUAC_OP_SUB:case LUAC_OP_MUL:
        case LUAC_OP_MOD:case LUAC_OP_POW:case LUAC_OP_DIV:
        case LUAC_OP_IDIV:case LUAC_OP_BAND:case LUAC_OP_BOR:
        case LUAC_OP_BXOR:case LUAC_OP_SHL:case LUAC_OP_SHR:
        case LUAC_OP_UNM:case LUAC_OP_BNOT:case LUAC_OP_NOT:
        case LUAC_OP_LEN:case LUAC_OP_TESTSET:
        case LUAC_OP_FORLOOP:case LUAC_OP_TFORLOOP:
        case LUAC_OP_CONCAT:
            return A==reg; /* 既读又写也算修改了值 */
        case LUAC_OP_VARARG:
            if(B<=1)return 0;
            for(int i=0;i<B-1;i++)if(A+i==reg)return 1;
            return 0;
        case LUAC_OP_SELF: return A==reg||A+1==reg;
        case LUAC_OP_LOADNIL:
            for(int i=0;i<=B;i++)if(A+i==reg)return 1;
            return 0;
        case LUAC_OP_CALL:
            if(C<=1)return 0;
            for(int i=0;i<C-1;i++)if(A+i==reg)return 1;
            return 0;
        default: return 0;
    }
}

static int ins_writes_reg(unsigned int ins, int reg) {'''
s = s.replace(old, new, 1)

# Replace ins_writes_reg with ins_modifies_reg in live-out analysis (both places)
s = s.replace(
    '''            int written_in_block=0;
            for(int i=start;i<end;i++){
                if(ins_writes_reg(p->code[i],r)){written_in_block=1;break;}
            }
            if(!written_in_block)continue;
            for(int i=end;i<p->sizecode;i++){
                if(ins_reads_reg(p->code[i],r)){live_after=1;break;}
                if(ins_writes_reg(p->code[i],r))break; /* 被重新赋值，不再依赖块中的值 */
            }''',
    '''            int written_in_block=0;
            for(int i=start;i<end;i++){
                if(ins_modifies_reg(p->code[i],r)){written_in_block=1;break;}
            }
            if(!written_in_block)continue;
            for(int i=end;i<p->sizecode;i++){
                if(ins_reads_reg(p->code[i],r)){live_after=1;break;}
                if(ins_modifies_reg(p->code[i],r))break; /* 被重新赋值，不再依赖块中的值 */
            }''',
    1
)

# Also replace in the logging section
s = s.replace(
    '''                int written_in_block=0;
                for(int i=start;i<end;i++){
                    if(ins_writes_reg(p->code[i],r)){written_in_block=1;break;}
                }
                if(!written_in_block)continue;
                for(int i=end;i<p->sizecode;i++){
                    if(ins_reads_reg(p->code[i],r)){DBG("  live-out reg R%d first read at pos %d (op=%d)\\n",r,i,p->code[i]&0x3F);break;}
                    if(ins_writes_reg(p->code[i],r)){DBG("  reg R%d re-written at pos %d (op=%d) before read\\n",r,i,p->code[i]&0x3F);break;}
                }''',
    '''                int written_in_block=0;
                for(int i=start;i<end;i++){
                    if(ins_modifies_reg(p->code[i],r)){written_in_block=1;break;}
                }
                if(!written_in_block)continue;
                for(int i=end;i<p->sizecode;i++){
                    if(ins_reads_reg(p->code[i],r)){DBG("  live-out reg R%d first read at pos %d (op=%d)\\n",r,i,p->code[i]&0x3F);break;}
                    if(ins_modifies_reg(p->code[i],r)){DBG("  reg R%d re-written at pos %d (op=%d) before read\\n",r,i,p->code[i]&0x3F);break;}
                }''',
    1
)

open(p, 'w', encoding='utf-8').write(s)
print('added ins_modifies_reg and used it in live-out analysis')
