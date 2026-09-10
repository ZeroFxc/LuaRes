/*
** for_loop_unroll.c - 数值 for 循环无损展开
**
** 把 FORPREP+FORLOOP 配对展开为普通指令，破坏反编译器依赖的
** "FORPREP A 与 FORLOOP A 寄存器一致 + 配对跳转" 特征。
**
** FORPREP A,sBx 语义: R(A)-=R(A+2); pc+=sBx (跳转到 FORLOOP)
** FORLOOP A,sBx 语义: R(A)+=R(A+2);
**   if (step>0 ? idx<=limit : limit<=idx) then { pc+=sBx; R(A+3)=R(A) }
**
** 展开后 (仅处理 step 为正常量的情况):
**   FORPREP -> SUB R(A),R(A),R(A+2) + JMP sBx (sBx 不变)
**   FORLOOP -> ADD R(A),R(A),R(A+2)
**              LE 0,R(A),R(A+1)       ; idx <= limit?
**              JMP +1                  ; true -> 跳转到 MOVE
**              JMP +2                  ; false -> 跳出循环
**              MOVE R(A+3),R(A)       ; 设置循环变量
**              JMP (orig_sBx - 4)     ; 跳回循环体
**
** 只展开 step 为正常量的 for 循环 (最常见情况)。
** step 为负、零或非常量时跳过不展开。
*/
#include <stdlib.h>
#include "obf_util.h"

#define FOR_LOOP_UNROLL_DEBUG 0

/* 检查 pos 位置的指令是否是 LOADK R(reg), k，返回常量索引或 -1 */
static int get_loadk_const(luac_Proto *p, int pos, int reg) {
    if (pos < 0 || pos >= p->sizecode) return -1;
    unsigned int ins = p->code[pos];
    if ((ins & 0x3F) != LUAC_OP_LOADK) return -1;
    int a = (ins >> 6) & 0xFF;
    if (a != reg) return -1;
    return (ins >> 14) & 0x3FFFF;  /* Bx */
}

/* 检查常量是否为正数 */
static int is_k_positive(luac_Proto *p, int kidx) {
    if (kidx < 0 || kidx >= p->sizek) return 0;
    int tag = p->k_tag[kidx];
    if (tag == 3) {  /* number float */
        return p->k_num[kidx] > 0.0;
    } else if (tag == 19) {  /* number int */
        return p->k_num[kidx] > 0.0;  /* k_num 存储 double，整数也存在这里 */
    }
    return 0;
}

/* 在 proto 中展开一个 for 循环对
** forprep_pos: FORPREP 指令位置 (0-based)
** forloop_pos: FORLOOP 指令位置 (0-based)
** 返回变更的指令数 (插入的指令数)
*/
static int unroll_one(luac_Proto *p, int forprep_pos, int forloop_pos) {
    unsigned int fp = p->code[forprep_pos];
    unsigned int fl = p->code[forloop_pos];
    int A = (fp >> 6) & 0xFF;
    int fp_sbx = ((fp >> 14) & 0x3FFFF) - 131071;
    int fl_sbx = ((fl >> 14) & 0x3FFFF) - 131071;

#if FOR_LOOP_UNROLL_DEBUG
    fprintf(stderr, "[unroll] fp=%d fl=%d A=%d fp_sbx=%d fl_sbx=%d\n",
            forprep_pos, forloop_pos, A, fp_sbx, fl_sbx);
#endif

    /* 先替换 FORLOOP (位置靠后，不影响 FORPREP 位置) */
    /* FORLOOP 替换为 6 条指令，比原来多 5 条 */
    {
        unsigned int new_ins[6];
        new_ins[0] = LUAC_ABC(LUAC_OP_ADD, A, A, A + 2);   /* idx += step */
        new_ins[1] = LUAC_ABC(LUAC_OP_LE, 1, A, A + 1);  /* A=1: 条件真时不跳过 */     /* idx <= limit? */
        new_ins[2] = LUAC_AsBx(LUAC_OP_JMP, 0, 1);           /* true -> MOVE */
        new_ins[3] = LUAC_AsBx(LUAC_OP_JMP, 0, 2);           /* false -> loop end */
        new_ins[4] = LUAC_ABC(LUAC_OP_MOVE, A + 3, A, 0);    /* loop var = idx */
        new_ins[5] = LUAC_AsBx(LUAC_OP_JMP, 0, fl_sbx - 5);  /* jump back to loop body */

        /* 替换 FORLOOP: 先在 forloop_pos+1 插入 5 条，再修改 forloop_pos */
        obf_code_insert(p, forloop_pos + 2, &new_ins[1], 5);  /* 1-based pos = forloop_pos+2 */
        p->code[forloop_pos] = new_ins[0];
    }

    /* FORLOOP 替换后，FORPREP 位置不变 (因为 FORLOOP 在 FORPREP 之后) */
    /* 替换 FORPREP 为 2 条指令，比原来多 1 条 */
    {
        unsigned int new_ins[2];
        new_ins[0] = LUAC_ABC(LUAC_OP_SUB, A, A, A + 2);   /* init -= step */
        new_ins[1] = LUAC_AsBx(LUAC_OP_JMP, 0, fp_sbx);      /* jump to FORLOOP (sBx 不变) */

        obf_code_insert(p, forprep_pos + 2, &new_ins[1], 1);  /* 1-based pos = forprep_pos+2 */
        p->code[forprep_pos] = new_ins[0];
    }

    return 6;  /* 总共插入 6 条指令 (FORLOOP 多 5 条 + FORPREP 多 1 条) */
}

static int unroll_function(luac_Proto *p) {
    int changes = 0;
    int i = 0;
    while (i < p->sizecode) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        if (op == LUAC_OP_FORPREP) {
            int A = (ins >> 6) & 0xFF;
            int sbx = ((ins >> 14) & 0x3FFFF) - 131071;
            int forloop_pos = i + 1 + sbx;  /* 跳转目标 */

            /* 验证跳转目标是 FORLOOP，且 A 寄存器一致 */
            if (forloop_pos >= 0 && forloop_pos < p->sizecode) {
                unsigned int fl = p->code[forloop_pos];
                int fl_op = fl & 0x3F;
                int fl_A = (fl >> 6) & 0xFF;
                if (fl_op == LUAC_OP_FORLOOP && fl_A == A) {
                    /* 检查 step 是否为正常量:
                    ** step 在 R(A+2)，通常由 FORPREP 之前的 LOADK 加载 */
                    int step_kidx = -1;
                    /* 向前查找 LOADK R(A+2) */
                    for (int j = i - 1; j >= 0 && j >= i - 8; j--) {
                        int kidx = get_loadk_const(p, j, A + 2);
                        if (kidx >= 0) { step_kidx = kidx; break; }
                    }
                    if (step_kidx >= 0 && is_k_positive(p, step_kidx)) {
                        int n = unroll_one(p, i, forloop_pos);
                        changes += n;
                        /* 展开后 i 位置的指令已改变，跳过展开的区域 */
                        i += 2;  /* FORPREP 替换为 2 条指令 */
                        continue;
                    }
#if FOR_LOOP_UNROLL_DEBUG
                    else {
                        fprintf(stderr, "[unroll] skip: step not positive const (fp=%d A=%d step_kidx=%d)\n",
                                i, A, step_kidx);
                    }
#endif
                }
            }
        }
        i++;
    }
    return changes;
}

int for_loop_unroll_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int n = unroll_function(p);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        n += unroll_function(p->p[i]);

    lua_pushinteger(L, n);
    return 1;
}
