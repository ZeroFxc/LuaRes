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
** 展开后每个配对变为:
**   SUB  R(A),R(A),R(A+2) ; JMP -> ADD                 (原 FORPREP)
**   ADD  R(A),R(A),R(A+2) ; LE 1,R(A),R(A+1)
**   JMP -> MOVE (真) ; JMP -> 循环退出 (假)
**   MOVE R(A+3),R(A)   ; JMP -> 循环体 (真回跳)        (原 FORLOOP)
**
** 正确性要点 (兼容 cfg_shuffle 等块重排模块):
**  1) 不假设 FORPREP 在 FORLOOP 之前, 也不假设循环体在 FORLOOP 之前。
**     块重排后 FORLOOP 可能位于 FORPREP 之前(倒置), 也可能向前跳(sBx>0)。
**     因此: 按两个锚点的"物理位置降序"插入(先处理靠后锚点, 其插入不会
**     移动另一锚点); 所有新 JMP 最后用统一位移公式按绝对目标位置回填。
**  2) 只在 FORPREP 所属同一基本块内向前识别 init/limit/step 的 LOADK,
**     遇到块边界(跳转目标/终止指令)即停, 避免误抓无关块常量。
**  step 为负/零/非常量、或初始化三连不完整时跳过不展开。
*/
#include <stdlib.h>
#include "obf_util.h"

#define FOR_LOOP_UNROLL_DEBUG 0

static int flu_is_jump(int op) { return op == 30 || op == 39 || op == 40 || op == 42; }
static int flu_is_terminator(int op) {
    return op == 30 || op == 37 || op == 38 || op == 39 || op == 40 || op == 42;
}

/* 检查 pos 位置是否 LOADK R(reg), 返回常量索引或 -1 */
static int get_loadk_const(luac_Proto *p, int pos, int reg) {
    if (pos < 0 || pos >= p->sizecode) return -1;
    unsigned int ins = p->code[pos];
    if ((ins & 0x3F) != LUAC_OP_LOADK) return -1;
    if (((ins >> 6) & 0xFF) != reg) return -1;
    return (ins >> 14) & 0x3FFFF;
}

static double get_k_number(luac_Proto *p, int kidx) {
    if (kidx < 0 || kidx >= p->sizek) return 0.0;
    int tag = p->k_tag[kidx];
    if (tag == 3 || tag == 19) return p->k_num[kidx];
    return 0.0;
}

static int is_k_positive(luac_Proto *p, int kidx) {
    if (kidx < 0 || kidx >= p->sizek) return 0;
    int tag = p->k_tag[kidx];
    if (tag == 3 || tag == 19) return p->k_num[kidx] > 0.0;
    return 0;
}

/* 展开一个 FORPREP/FORLOOP 配对。fp0=FORPREP 当前位置, fl0=FORLOOP 当前位置
** (二者物理先后不限); 返回插入指令数(固定 6)。 */
static int unroll_one(luac_Proto *p, int fp0, int fl0) {
    unsigned int fp_ins = p->code[fp0];
    int A = (fp_ins >> 6) & 0xFF;
    int fp_sbx = ((fp_ins >> 14) & 0x3FFFF) - 131071;
    int fl_sbx = ((p->code[fl0] >> 14) & 0x3FFFF) - 131071;
    int t_body0 = fl0 + 1 + fl_sbx;   /* FORLOOP 条件真目标(循环体)当前绝对位置 */

    /* 两个插入点(1-based 语义 pos0=锚点+1) */
    int pos_fp = fp0 + 1, n_fp = 1;
    int pos_fl = fl0 + 1, n_fl = 5;

    /* 展开 FORLOOP: 原地改 ADD, 其后插入 LE/JMP/JMP/MOVE/JMP (JMP 先占位) */
    unsigned int fl_tail[5] = {
        LUAC_ABC(LUAC_OP_LE, 1, A, A + 1),
        LUAC_AsBx(LUAC_OP_JMP, 0, 0),
        LUAC_AsBx(LUAC_OP_JMP, 0, 0),
        LUAC_ABC(LUAC_OP_MOVE, A + 3, A, 0),
        LUAC_AsBx(LUAC_OP_JMP, 0, 0),
    };
    /* 展开 FORPREP: 原地改 SUB, 其后插入 1 条 JMP(占位) */
    unsigned int fp_tail[1] = { LUAC_AsBx(LUAC_OP_JMP, 0, 0) };

    /* 按物理位置降序: 先处理靠后锚点, 其插入不会移动靠前锚点 */
    if (fp0 > fl0) {
        p->code[fp0] = LUAC_ABC(LUAC_OP_SUB, A, A, A + 2);
        obf_code_insert(p, pos_fp + 1, fp_tail, n_fp);
        p->code[fl0] = LUAC_ABC(LUAC_OP_ADD, A, A, A + 2);
        obf_code_insert(p, pos_fl + 1, fl_tail, n_fl);
    } else {
        p->code[fl0] = LUAC_ABC(LUAC_OP_ADD, A, A, A + 2);
        obf_code_insert(p, pos_fl + 1, fl_tail, n_fl);
        p->code[fp0] = LUAC_ABC(LUAC_OP_SUB, A, A, A + 2);
        obf_code_insert(p, pos_fp + 1, fp_tail, n_fp);
    }

    /* 统一位移: 原始位置 x 在两次插入后的最终位置 */
    #define FLU_SHIFT(x) ((x) + (((x) >= pos_fp) ? n_fp : 0) + (((x) >= pos_fl) ? n_fl : 0))

    int sub_p  = FLU_SHIFT(fp0);
    int jfp_p  = sub_p + 1;
    int add_p  = FLU_SHIFT(fl0);
    int jt_p   = add_p + 2;   /* 真 JMP */
    int jf_p   = add_p + 3;   /* 假 JMP */
    int mv_p   = add_p + 4;
    int jb_p   = add_p + 5;   /* 回循环体 JMP */
    int exit_p = FLU_SHIFT(fl0 + 1);          /* 原 FORLOOP 物理下一条 = 退出路径 */
    int body_p = FLU_SHIFT(t_body0);          /* 循环体目标最终位置 */

    p->code[jfp_p] = LUAC_AsBx(LUAC_OP_JMP, 0, add_p - jfp_p - 1);
    p->code[jt_p]  = LUAC_AsBx(LUAC_OP_JMP, 0, mv_p - jt_p - 1);
    p->code[jf_p]  = LUAC_AsBx(LUAC_OP_JMP, 0, exit_p - jf_p - 1);
    p->code[jb_p]  = LUAC_AsBx(LUAC_OP_JMP, 0, body_p - jb_p - 1);

#if FOR_LOOP_UNROLL_DEBUG
    fprintf(stderr,"[unroll] fp=%d fl=%d A=%d add=%d body=%d exit=%d\n",fp0,fl0,A,add_p,body_p,exit_p);
#endif
    #undef FLU_SHIFT
    return 6;
}

/* 重建基本块起点标记(跳转目标位置) */
static void flu_mark_starts(luac_Proto *p, char *mark) {
    for (int k = 0; k < p->sizecode; k++) mark[k] = 0;
    for (int k = 0; k < p->sizecode; k++) {
        int op = p->code[k] & 0x3F;
        if (flu_is_jump(op)) {
            int sbx = ((p->code[k] >> 14) & 0x3FFFF) - 131071;
            int t = k + 1 + sbx;
            if (t >= 0 && t < p->sizecode) mark[t] = 1;
        }
    }
}

static int unroll_function(luac_Proto *p) {
    int changes = 0;
    char *is_block_start = (char *)calloc(p->sizecode > 0 ? p->sizecode : 1, 1);
    flu_mark_starts(p, is_block_start);

    int i = 0;
    while (i < p->sizecode) {
        unsigned int ins = p->code[i];
        if ((ins & 0x3F) == LUAC_OP_FORPREP) {
            int A = (ins >> 6) & 0xFF;
            int sbx = ((ins >> 14) & 0x3FFFF) - 131071;
            int forloop_pos = i + 1 + sbx;

            if (forloop_pos >= 0 && forloop_pos < p->sizecode) {
                unsigned int fl = p->code[forloop_pos];
                if ((fl & 0x3F) == LUAC_OP_FORLOOP && ((fl >> 6) & 0xFF) == A) {
                    /* 仅在 FORPREP 同一块内向前识别 init/limit/step LOADK */
                    int step_kidx = -1, start_kidx = -1, limit_kidx = -1;
                    for (int j = i - 1; j >= 0; j--) {
                        if (is_block_start[j]) break;
                        int jop = p->code[j] & 0x3F;
                        if (flu_is_terminator(jop)) break;
                        if (step_kidx < 0) {
                            int kk = get_loadk_const(p, j, A + 2);
                            if (kk >= 0) step_kidx = kk;
                        }
                        int sa = get_loadk_const(p, j, A);
                        int la = get_loadk_const(p, j, A + 1);
                        if (sa >= 0) start_kidx = sa;
                        if (la >= 0) limit_kidx = la;
                    }

                    int ok = (step_kidx >= 0) && is_k_positive(p, step_kidx);
                    if (ok && start_kidx >= 0 && limit_kidx >= 0) {
                        double sv = get_k_number(p, start_kidx);
                        double lv = get_k_number(p, limit_kidx);
                        if (sv > lv) ok = 0;   /* 正 step 且 start>limit, 循环不执行 */
                    }

                    if (ok) {
                        changes += unroll_one(p, i, forloop_pos);
                        /* 插入后 sizecode 增大, 标记缓冲区必须同步扩容, 否则越界写 */
                        is_block_start = (char *)realloc(is_block_start, p->sizecode);
                        flu_mark_starts(p, is_block_start);
                    }
                }
            }
        }
        i++;
    }
    free(is_block_start);
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
