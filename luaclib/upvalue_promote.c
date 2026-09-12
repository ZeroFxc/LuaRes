/*
** upvalue_promote.c - upvalue 升降
** 把局部变量提升为 upvalue：IIFE 包装基本块，外部变量变成闭包 upvalue
*/
#include <stdlib.h>
#include <string.h>
#include "obf_util.h"

#define UPVAL_DEBUG 0
#if UPVAL_DEBUG
#define DBG(...) fprintf(stderr, __VA_ARGS__)
#else
#define DBG(...) ((void)0)
#endif

static int ins_reads_reg(unsigned int ins, int reg) {
    int op=ins&0x3F,A=(ins>>6)&0xFF,B=(ins>>23)&0x1FF,C=(ins>>14)&0x1FF;
    switch(op){
        case LUAC_OP_MOVE: return B==reg;
        case LUAC_OP_GETTABUP: return(C<256&&C==reg);
        case LUAC_OP_GETTABLE: return B==reg||(C<256&&C==reg);
        case LUAC_OP_SETTABUP: return(B<256&&B==reg)||(C<256&&C==reg);
        case LUAC_OP_SETUPVAL: return A==reg;
        case LUAC_OP_SETTABLE: return A==reg||(B<256&&B==reg)||(C<256&&C==reg);
        case LUAC_OP_SELF: return B==reg||(C<256&&C==reg);
        case LUAC_OP_ADD:case LUAC_OP_SUB:case LUAC_OP_MUL:
        case LUAC_OP_MOD:case LUAC_OP_POW:case LUAC_OP_DIV:
        case LUAC_OP_IDIV:case LUAC_OP_BAND:case LUAC_OP_BOR:
        case LUAC_OP_BXOR:case LUAC_OP_SHL:case LUAC_OP_SHR:
            return(B<256&&B==reg)||(C<256&&C==reg);
        case LUAC_OP_UNM:case LUAC_OP_BNOT:case LUAC_OP_NOT:case LUAC_OP_LEN:
            return B==reg;
        case LUAC_OP_CONCAT: return(reg>=B&&reg<=C);
        case LUAC_OP_EQ:case LUAC_OP_LT:case LUAC_OP_LE:
            return(B<256&&B==reg)||(C<256&&C==reg);
        case LUAC_OP_TEST: return A==reg;
        case LUAC_OP_TESTSET: return B==reg;
        case LUAC_OP_CALL:case LUAC_OP_TAILCALL:
            if(A==reg)return 1;
            if(B==1)return 0; if(B==0)return reg>A;
            for(int i=0;i<B-1;i++)if(A+1+i==reg)return 1;
            return 0;
        case LUAC_OP_RETURN:
            if(B==1)return 0; if(B==0)return reg>=A;
            for(int i=0;i<B-1;i++)if(A+i==reg)return 1;
            return 0;
        case LUAC_OP_FORLOOP:case LUAC_OP_FORPREP:
            return A==reg||A+1==reg||A+2==reg||A+3==reg;
        case LUAC_OP_TFORCALL: return A==reg||A+1==reg||A+2==reg;
        case LUAC_OP_TFORLOOP: return A+1==reg;
        case LUAC_OP_SETLIST:
            if(B==0)return 0;
            return(reg>=A+1&&reg<=A+B);
        default: return 0;
    }
}

/* 活跃变量分析用：是否修改了寄存器的值（既读又写也算修改） */
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
            if(B==1)return 0; if(B==0)return reg>=A;
            for(int i=0;i<B-1;i++)if(A+i==reg)return 1;
            return 0;
        case LUAC_OP_SELF: return A==reg||A+1==reg;
        case LUAC_OP_LOADNIL:
            for(int i=0;i<=B;i++)if(A+i==reg)return 1;
            return 0;
        case LUAC_OP_CALL:
            if(C==1)return 0; if(C==0)return reg>=A;
            for(int i=0;i<C-1;i++)if(A+i==reg)return 1;
            return 0;
        default: return 0;
    }
}

static int ins_writes_reg(unsigned int ins, int reg) {
    int op=ins&0x3F,A=(ins>>6)&0xFF,B=(ins>>23)&0x1FF,C=(ins>>14)&0x1FF;
    switch(op){
        case LUAC_OP_MOVE:case LUAC_OP_LOADK:case LUAC_OP_LOADKX:
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
            return A==reg;
        case LUAC_OP_CONCAT:
            /* CONCAT A B C: R(A)=R(B)....R(C). If A in [B,C], read-before-write, don't count as write */
            if(reg==A && A>=B && A<=C)return 0;
            return A==reg;
        case LUAC_OP_VARARG:
            if(B==1)return 0; if(B==0)return reg>=A;
            for(int i=0;i<B-1;i++)if(A+i==reg)return 1;
            return 0;
        case LUAC_OP_SELF: return A==reg||A+1==reg;
        case LUAC_OP_LOADNIL:
            for(int i=0;i<=B;i++)if(A+i==reg)return 1;
            return 0;
        case LUAC_OP_CALL:
            if(C==1)return 0; if(C==0)return reg>=A;
            for(int i=0;i<C-1;i++)if(A+i==reg)return 1;
            return 0;
        default: return 0;
    }
}

static int is_control_flow(unsigned int ins){
    int op=ins&0x3F;
    return op==LUAC_OP_JMP||op==LUAC_OP_RETURN||op==LUAC_OP_CLOSURE||
           op==LUAC_OP_FORLOOP||op==LUAC_OP_FORPREP||op==LUAC_OP_TFORLOOP||
           op==LUAC_OP_TAILCALL||op==LUAC_OP_EXTRAARG;
}

static int add_sub_proto(luac_Proto *parent, luac_Proto *child){
    parent->p=realloc(parent->p,sizeof(luac_Proto*)*(parent->sizep+1));
    parent->p[parent->sizep]=child;
    return parent->sizep++;
}

static void fix_jumps_replace(unsigned int *code,int code_len,
                               int start,int old_len,int new_len){
    int delta=new_len-old_len;
    if(delta==0)return;
    int old_end=start+old_len,new_end=start+new_len;
    DBG("[FIX] start=%d old_len=%d new_len=%d delta=%d old_end=%d new_end=%d code_len=%d\n",
        start,old_len,new_len,delta,old_end,new_end,code_len);
    for(int i=0;i<code_len;i++){
        int op=code[i]&0x3F;
        if(op!=LUAC_OP_JMP&&op!=LUAC_OP_FORLOOP&&
           op!=LUAC_OP_FORPREP&&op!=LUAC_OP_TFORLOOP)continue;
        if(i>=start&&i<new_end){DBG("[FIX] skip JMP at %d (inside replace region)\n",i);continue;}
        int old_i=(i<start)?i:i-delta;
        int sbx=(int)(code[i]>>14)-131071;
        int old_target=old_i+sbx+1;
        int new_target;
        if(old_target<=start)new_target=old_target;
        else if(old_target>=old_end)new_target=old_target+delta;
        else {DBG("[FIX] SKIP JMP at %d op=%d old_i=%d sbx=%d old_target=%d (target inside region [%d,%d))\n",
            i,op,old_i,sbx,old_target,start,old_end);continue;}
        int new_sbx=new_target-i-1;
        if(new_sbx!=sbx){
            DBG("[FIX] JMP at %d op=%d: old_i=%d sbx=%d->%d target=%d->%d\n",
                i,op,old_i,sbx,new_sbx,old_target,new_target);
        }
        code[i]=(code[i]&0x3FFF)|((unsigned int)(new_sbx+131071)<<14);
    }
}

static int promote_in_proto(lua_State *L, luac_Proto *p, int count){
    if(!p->code||p->sizecode<3)return 0;

    /* identify state register: most frequently read by EQ (flatten state machine) */
    int eq_read_count[256] = {0};
    for(int i=0;i<p->sizecode;i++){
        int op=p->code[i]&0x3F;
        if(op==LUAC_OP_EQ||op==LUAC_OP_LT||op==LUAC_OP_LE){
            int B=(p->code[i]>>23)&0x1FF, C=(p->code[i]>>14)&0x1FF;
            if(B<256) eq_read_count[B]++;
            if(C<256) eq_read_count[C]++;
        }
    }
    int state_reg=-1, max_eq=0;
    for(int r=0;r<256;r++){ if(eq_read_count[r]>max_eq){max_eq=eq_read_count[r]; state_reg=r;} }
    DBG("[UPVAL] detected state_reg=R%d (eq_read=%d)\n", state_reg, max_eq);

    int changed=0,pos=0,attempts=0;
    while(changed<count&&attempts<count*20&&pos<p->sizecode-2){
        attempts++;
        int start=pos,end=start;
        while(end<p->sizecode&&!is_control_flow(p->code[end])){
            int op=p->code[end]&0x3F;
            if(op==LUAC_OP_EQ||op==LUAC_OP_LT||op==LUAC_OP_LE||
               op==LUAC_OP_TEST||op==LUAC_OP_TESTSET||op==LUAC_OP_LOADKX||
               op==LUAC_OP_TFORCALL)break;
            if(op==LUAC_OP_SETLIST&&((p->code[end]>>14)&0x1FF)==0)break;
            end++;
            if(end-start>12)break;
        }
        if(end-start<1){DBG("[UPVAL] block too short at %d len=%d\n",pos,end-start);pos=end+1;continue;}
        {
            int in_loop=0;
            for(int lj=0;lj<p->sizecode;lj++){
                int lop=p->code[lj]&0x3F;
                if(lop==LUAC_OP_JMP||lop==LUAC_OP_FORLOOP||
                   lop==LUAC_OP_FORPREP||lop==LUAC_OP_TFORLOOP){
                    int lsbx=((p->code[lj]>>14)&0x3FFFF)-131071;
                    if(1){
                        int ltarget=lj+1+lsbx;
                        if((lj<start&&ltarget>=end)||(lj>=end&&ltarget<=start)||
                           (ltarget>start&&ltarget<end)){in_loop=1;break;}
                    }
                }
            }
            if(in_loop){pos=end+1;continue;}
        }
        int has_call_ret=0;
        for(int i=start;i<end;i++){
            int op=p->code[i]&0x3F;
            if((op==LUAC_OP_CALL||op==LUAC_OP_TAILCALL)&&((p->code[i]>>14)&0x1FF)>1){
                has_call_ret=1;break;
            }
        }
        if(has_call_ret){DBG("[UPVAL] block has call with ret at %d\n",start);pos=end+1;continue;}
        /* 块中包含 NEWTABLE 时跳过：表创建必须留在父栈帧，IIFE 不会把表引用传回 */
        int has_newtable=0;
        for(int i=start;i<end;i++){
            if((p->code[i]&0x3F)==LUAC_OP_NEWTABLE){has_newtable=1;break;}
        }
        if(has_newtable){DBG("[UPVAL] block has NEWTABLE at %d, skip\n",start);pos=end+1;continue;}
        /* SETLIST B=0 depends on L->top, differs between parent and child proto */
        int has_setlist_b0=0;
        for(int i=start;i<end;i++){
            if((p->code[i]&0x3F)==LUAC_OP_SETLIST && ((p->code[i]>>23)&0x1FF)==0){has_setlist_b0=1;break;}
        }
        if(has_setlist_b0){DBG("[UPVAL] block has SETLIST B=0 at %d, skip\n",start);pos=end+1;continue;}
        /* 活跃变量分析：收集 live-out 寄存器，IIFE 通过返回值传回 */
        int live_out_regs[32];
        int n_live_out=0;
        for(int r=0;r<p->maxstacksize && n_live_out<32;r++){
            if(r==state_reg) continue; /* state reg is passed via JMP, not return value */
            int written_in_block=0;
            for(int i=start;i<end;i++){
                if(ins_modifies_reg(p->code[i],r)){written_in_block=1;break;}
            }
            if(!written_in_block)continue;
            for(int i=end;i<p->sizecode;i++){
                if(ins_reads_reg(p->code[i],r)){live_out_regs[n_live_out++]=r;break;}
                if(ins_modifies_reg(p->code[i],r))break; /* 被重新赋值，不再依赖块中的值 */
            }
        }
        if(n_live_out>4){
            DBG("[UPVAL] block [%d,%d) has %d live-out regs (>1), skip\n",start,end,n_live_out);
            pos=end+1;continue;
        }
        if(n_live_out>0) DBG("[UPVAL] block [%d,%d) WILL RETURN live_out R%d\n",start,end,live_out_regs[0]);
        /* 前向数据流分析：第一次出现是读才算外部变量（处理先读后写） */
        int ext_regs[32],next=0;
        for(int r=0;r<p->maxstacksize;r++){
            int first_read=-1,first_write=-1;
            for(int i=start;i<end;i++){
                if(first_read<0 && ins_reads_reg(p->code[i],r))first_read=i;
                if(first_write<0 && ins_writes_reg(p->code[i],r))first_write=i;
            }
            if(first_read>=0 && (first_write<0 || first_read<=first_write)){
                if(next<32)ext_regs[next++]=r;
            }
        }
        DBG("[UPVAL] block [%d,%d) len=%d maxstack=%d ext_count=%d",start,end,end-start,p->maxstacksize,next);
        for(int _ei=0;_ei<next;_ei++)DBG(" R%d",ext_regs[_ei]);
        DBG("\n");
        /* Dump first 3 blocks instructions for debugging */
        static int dbg_block_count=0;
        if(UPVAL_DEBUG){
            dbg_block_count++;
            DBG("[DBG_BLOCK %d] instructions:\n",dbg_block_count);
            for(int _di=start;_di<end;_di++){
                unsigned int _ins=p->code[_di];
                DBG("  [%d] op=%d A=%d B=%d C=%d\n",_di,_ins&0x3F,(_ins>>6)&0xFF,(_ins>>23)&0x1FF,(_ins>>14)&0x1FF);
            }
            if(end<p->sizecode){
                unsigned int _ins=p->code[end];
                DBG("  [%d] NEXT op=%d A=%d B=%d C=%d\n",end,_ins&0x3F,(_ins>>6)&0xFF,(_ins>>23)&0x1FF,(_ins>>14)&0x1FF);
            }
        }
        if(next<=0){pos=end+1;continue;}
        int ext_written=0;
        for(int e=0;e<next;e++)
            for(int i=start;i<end;i++)
                if(ins_writes_reg(p->code[i],ext_regs[e])){ext_written=1;break;}
        if(ext_written){pos=end+1;continue;}

        int block_len=end-start;

        /* 用 obf_compile_subproto 创建合法 proto 基础 */
        luac_Proto *child=NULL;
        if(obf_compile_subproto(L,"return function() return end",&child)==0||!child){
            DBG("[UPVAL] obf_compile_subproto FAILED at block %d\n",start);
            pos=end+1;continue;
        }
        DBG("[UPVAL] obf_compile_subproto OK, child code size=%d maxstack=%d\n",child->sizecode,child->maxstacksize);

        /* 立即深拷贝 source：obf_compile_subproto 中 main_p 可能被 GC，source 会被释放 */
        if(child->source && child->source_len>0){
            char *ns=malloc(child->source_len+1);
            memcpy(ns,child->source,child->source_len);
            ns[child->source_len]='\0';
            child->source=ns;
        }else{child->source=NULL;child->source_len=0;}
        child->linedefined=0; child->lastlinedefined=0;

        /* 复制常量池 */
        if(p->sizek>0){
            free(child->k_tag);free(child->k_str);free(child->k_str_len);
            free(child->k_num);free(child->k_bool);free(child->k_int);
            child->sizek=p->sizek;
            child->k_tag=malloc(sizeof(int)*p->sizek);
            child->k_str=malloc(sizeof(char*)*p->sizek);
            child->k_str_len=malloc(sizeof(int)*p->sizek);
            child->k_num=malloc(sizeof(double)*p->sizek);
            child->k_bool=malloc(sizeof(int)*p->sizek);
            child->k_int=malloc(sizeof(int64_t)*p->sizek);
            memcpy(child->k_tag,p->k_tag,sizeof(int)*p->sizek);
            memcpy(child->k_num,p->k_num,sizeof(double)*p->sizek);
            memcpy(child->k_bool,p->k_bool,sizeof(int)*p->sizek);
            if(p->k_int) memcpy(child->k_int,p->k_int,sizeof(int64_t)*p->sizek);
            else memset(child->k_int,0,sizeof(int64_t)*p->sizek);
            for(int ci=0;ci<p->sizek;ci++){
                if((p->k_tag[ci]==4||p->k_tag[ci]==20)&&p->k_str[ci]){
                    child->k_str[ci]=malloc(p->k_str_len[ci]+1);
                    memcpy(child->k_str[ci],p->k_str[ci],p->k_str_len[ci]);
                    child->k_str[ci][p->k_str_len[ci]]='\0';
                    child->k_str_len[ci]=p->k_str_len[ci];
                }else{child->k_str[ci]=NULL;child->k_str_len[ci]=0;}
            }
        }

        /* 设置 upvalue: _ENV at 0, external vars at 1..next */
        free(child->upval_name);free(child->upval_name_len);
        free(child->upval_instack);free(child->upval_idx);
        child->sizeupvalues=next+1;
        int nup=next+1;
        child->upval_name=malloc(sizeof(char*)*nup);
        child->upval_name_len=malloc(sizeof(int)*nup);
        child->upval_instack=malloc(sizeof(unsigned char)*nup);
        child->upval_idx=malloc(sizeof(unsigned char)*nup);
        child->upval_name[0]=malloc(5);
        memcpy(child->upval_name[0],"_ENV",5);
        child->upval_name_len[0]=4;
        child->upval_instack[0]=0;child->upval_idx[0]=0;
        for(int i=0;i<next;i++){
            char *nm=malloc(4);
            nm[0]='a'+(obf_rand()%26);nm[1]='a'+(obf_rand()%26);
            nm[2]='a'+(obf_rand()%26);nm[3]='\0';
            child->upval_name[i+1]=nm;child->upval_name_len[i+1]=3;
            child->upval_instack[i+1]=1;child->upval_idx[i+1]=ext_regs[i];
        }

        /* maxstacksize for child proto */
        int mr=2;
        for(int i=start;i<end;i++){
            int A=(p->code[i]>>6)&0xFF,B=(p->code[i]>>23)&0x1FF,C=(p->code[i]>>14)&0x1FF;
            if(A+1>mr)mr=A+1;
            if(B<256&&B+1>mr)mr=B+1;
            if(C<256&&C+1>mr)mr=C+1;
        }
        for(int i=0;i<next;i++)if(ext_regs[i]+1>mr)mr=ext_regs[i]+1;

        /* 子 proto 指令：GETUPVAL + 基本块 + MOVE live-out + RETURN */
        free(child->code);
        int ret_tmp = mr;
        int total_ins=next+block_len+n_live_out+1;
        child->code=malloc(sizeof(unsigned int)*total_ins);
        child->sizecode=total_ins;
        for(int i=0;i<next;i++)
            child->code[i]=LUAC_ABC(LUAC_OP_GETUPVAL,ext_regs[i],i+1,0);
        memcpy(&child->code[next],&p->code[start],sizeof(unsigned int)*block_len);
        int ci=next+block_len;
        for(int i=0;i<n_live_out;i++)
            child->code[ci++]=LUAC_ABC(LUAC_OP_MOVE,ret_tmp+i,live_out_regs[i],0);
        child->code[ci]=LUAC_ABC(LUAC_OP_RETURN,ret_tmp,n_live_out+1,0);
        child->maxstacksize=ret_tmp+n_live_out;
        DBG("[UPVAL] child: ret_tmp=%d maxstack=%d total_ins=%d\n", ret_tmp, child->maxstacksize, total_ins);

        /* 剥离调试信息：code 长度已变，旧 lineinfo/locvars 不匹配会导致 dump 越界崩溃 */
        free(child->lineinfo); child->lineinfo=NULL; child->sizelineinfo=0;
        free(child->locvar_name); child->locvar_name=NULL;
        free(child->locvar_name_len); child->locvar_name_len=NULL;
        free(child->locvar_startpc); child->locvar_startpc=NULL;
        free(child->locvar_endpc); child->locvar_endpc=NULL;
        child->sizelocvars=0;
        child->lineinfo_tbl=LUA_NOREF; child->locvars_tbl=LUA_NOREF;



        int proto_idx=obf_add_subproto(L,p,child);
        child=p->p[proto_idx];  /* raw 指针可能已被 luac_push_proto 转移所有权，改用 userdata 指针 */
        int old_max=p->maxstacksize;
        if(old_max+1>250){DBG("[UPVAL] skip: old_max+1>250 at %d\n",start);pos=end+1;continue;}
        int Rtmp=old_max;
        obf_ensure_stack(p,Rtmp+1+child->maxstacksize);
        DBG("[UPVAL] proto_idx=%d Rtmp=%d child_maxstack=%d parent_maxstack=%d->%d\n",
            proto_idx,Rtmp,child->maxstacksize,old_max,p->maxstacksize);

        /* dump block before */
        DBG("[UPVAL] BLOCK BEFORE at [%d,%d):\n",start,end);
        for(int _di=start;_di<end;_di++){
            unsigned int _ins=p->code[_di];
            DBG("  [%d] op=%d A=%d B=%d C=%d\n",_di,_ins&0x3F,(_ins>>6)&0xFF,(_ins>>23)&0x1FF,(_ins>>14)&0x1FF);
        }
        for(int di=start;di<end;di++){
            int dop=p->code[di]&0x3F,dA=(p->code[di]>>6)&0xFF,dB=(p->code[di]>>23)&0x1FF,dC=(p->code[di]>>14)&0x1FF;
            DBG("  [%d] op=%d A=%d B=%d C=%d\n",di,dop,dA,dB,dC);
        }
        /* dump child proto */
        DBG("[UPVAL] CHILD proto: sizecode=%d maxstack=%d sizek=%d nup=%d\n",
            child->sizecode,child->maxstacksize,child->sizek,child->sizeupvalues);
        for(int di=0;di<child->sizecode;di++){
            int dop=child->code[di]&0x3F,dA=(child->code[di]>>6)&0xFF,dB=(child->code[di]>>23)&0x1FF,dC=(child->code[di]>>14)&0x1FF;
            DBG("  child[%d] op=%d A=%d B=%d C=%d\n",di,dop,dA,dB,dC);
        }
        for(int ui=0;ui<child->sizeupvalues;ui++){
            DBG("  child upval[%d]: instack=%d idx=%d\n",ui,child->upval_instack[ui],child->upval_idx[ui]);
        }

        int replace_count=2+n_live_out;
        unsigned int *replace=malloc(sizeof(unsigned int)*replace_count);
        replace[0]=LUAC_ABx(LUAC_OP_CLOSURE,Rtmp,proto_idx);
        replace[1]=LUAC_ABC(LUAC_OP_CALL,Rtmp,1,n_live_out+1);
        DBG("[UPVAL] parent: Rtmp=%d CALL recv=%d\n", Rtmp, n_live_out+1);
        for(int i=n_live_out-1;i>=0;i--)
            replace[2+i]=LUAC_ABC(LUAC_OP_MOVE,live_out_regs[i],Rtmp+i,0);

        int delta=replace_count-block_len;
        if(delta>0){
            p->code=realloc(p->code,sizeof(unsigned int)*(p->sizecode+delta));
            memmove(&p->code[start+replace_count],&p->code[end],
                    sizeof(unsigned int)*(p->sizecode-end));
        }else if(delta<0){
            memmove(&p->code[start+replace_count],&p->code[end],
                    sizeof(unsigned int)*(p->sizecode-end));
        }
        memcpy(&p->code[start],replace,sizeof(unsigned int)*replace_count);
        p->sizecode+=delta;
        free(replace);

        fix_jumps_replace(p->code,p->sizecode,start,block_len,replace_count);

        /* dump code after replace (first 30 instructions) */
        DBG("[UPVAL] AFTER replace, sizecode=%d, first 30 ins:\n",p->sizecode);
        for(int di=0;di<(p->sizecode<30?p->sizecode:30);di++){
            int dop=p->code[di]&0x3F,dA=(p->code[di]>>6)&0xFF,dB=(p->code[di]>>23)&0x1FF,dC=(p->code[di]>>14)&0x1FF;
            int dsbx=((p->code[di]>>14)&0x3FFFF)-131071;
            if(dop==LUAC_OP_JMP||dop==LUAC_OP_FORLOOP||dop==LUAC_OP_FORPREP)
                DBG("  [%d] op=%d A=%d sbx=%d\n",di,dop,dA,dsbx);
            else
                DBG("  [%d] op=%d A=%d B=%d C=%d\n",di,dop,dA,dB,dC);
        }

        changed++;
        pos=start+replace_count+1;
        DBG("[UPVAL] block done, changed=%d, next pos=%d\n",changed,pos);
    }
    return changed;
}

int upvalue_promote_process(lua_State *L){
    luac_Proto *p=obf_check_proto(L);
    obf_invalidate_all_caches(L,p);
    int count=10;
    if(lua_gettop(L)>=2&&lua_istable(L,2)){
        lua_getfield(L,2,"count");
        if(lua_isnumber(L,-1))count=(int)lua_tointeger(L,-1);
        lua_pop(L,1);
    }
    int n=0;
    /* 只处理主 proto，不处理子 proto：子 proto 函数体被 IIFE 包装后返回值无法传回 */
    n+=promote_in_proto(L,p,count);
    lua_pushinteger(L,n);
    return 1;
}
