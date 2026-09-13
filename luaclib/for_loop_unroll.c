/*
** for_loop_unroll.c - 数值 for 循环无损展开（通用版）
**
** 把 FORPREP+FORLOOP 配对展开为普通算术/比较/跳转指令，破坏反编译器
** 依赖的 "FORPREP A 与 FORLOOP A 寄存器一致 + 配对跳转" 特征。
**
** FORPREP A,sBx 语义: R(A)-=R(A+2); pc+=sBx (跳转到 FORLOOP)
** FORLOOP A,sBx 语义: R(A)+=R(A+2);
**   if (R(A+2) > 0 ? R(A) <= R(A+1) : R(A+1) <= R(A))
**     then { pc+=sBx; R(A+3)=R(A) }   // 继续循环体
**
** 旧实现要求 FORPREP 前紧邻三条 init/limit/step 的数字 LOADK，且 step 必须
** 是编译期正常量：一旦 const_hide 等把 LOADK 改写、或块重排让 init LOADK
** 落在跳转目标（基本块起点）上，向前扫描就会漏抓而放弃展开，覆盖面很窄。
**
** 根因：展开变换本身只使用寄存器 R(A..A+2)（运行时它们已持有 init/limit/
** step），唯一需要提前知道的是比较方向，而方向只取决于 step 的符号——这完全
** 可以在运行时判断，无需任何编译期常量。本版因此：
**   - 不再向前识别 init/limit/step LOADK，不要求常量，不判断死循环；
**   - 用一个高位临时寄存器 T 现场造 0（MOVE T,step; SUB T,T,step），运行时
**     用 LT 判断 step>0 选择正/负步长的 LE 方向，与虚拟机内部判定完全一致
**     （step==0 走负方向）；
**   - 只要求 FORPREP 的 sBx 目标是同一 A 的 FORLOOP（配对未被破坏即可）。
**
** 展开布局（FORPREP 原地改 SUB，FORLOOP 原地改 ADD；fp 后插 1 条，fl 后插 11 条）：
**   FORPREP 处:  SUB R(A),R(A),R(A+2) ; JMP -> ADD
**   FORLOOP 处:  ADD R(A),R(A),R(A+2)
**                MOVE T,R(A+2); SUB T,T,R(A+2)         ; T = 0
**                LT  0,T,R(A+2); JMP -> NEG            ; 0<step 为真则落到 POS
**              POS: LE 1,R(A),R(A+1)  ; JMP -> MOVE    ; idx<=limit
**                JMP -> EXIT
**              NEG: LE 1,R(A+1),R(A)   ; JMP -> MOVE    ; limit<=idx
**                JMP -> EXIT
**             MOVE: MOVE R(A+3),R(A) ; JMP -> 循环体
**
** 兼容性：不假设两个锚点的物理先后，按物理位置降序插入（先处理靠后锚点，
** 其插入不移动另一锚点），所有新 JMP 最后用统一位移公式按绝对目标回填。
*/
#include <stdlib.h>
#include "obf_util.h"

#define FOR_LOOP_UNROLL_DEBUG 0

/* 展开一个 FORPREP/FORLOOP 配对。fp0=FORPREP 当前位置, fl0=FORLOOP 当前位置
** (二者物理先后不限); 返回插入指令数(固定 12: fp 后 1 + fl 后 11)。T=临时寄存器。 */
static int unroll_one(luac_Proto *p, int fp0, int fl0, int T) {
    unsigned int fp_ins = p->code[fp0];
    int A = (fp_ins >> 6) & 0xFF;
    int fl_sbx = ((p->code[fl0] >> 14) & 0x3FFFF) - 131071;
    int t_body0 = fl0 + 1 + fl_sbx;   /* FORLOOP 条件真目标(循环体)当前绝对位置 */

    /* FORLOOP 原地改 ADD，其后插入 11 条 */
    unsigned int fl_tail[11] = {
        LUAC_ABC(LUAC_OP_MOVE, T, A + 2, 0),        /* t1: T = step           */
        LUAC_ABC(LUAC_OP_SUB,  T, T, A + 2),        /* t2: T = T - step = 0   */
        LUAC_ABC(LUAC_OP_LT,   0, T, A + 2),        /* t3: (0 < step)? skip t4*/
        LUAC_AsBx(LUAC_OP_JMP, 0, 0),               /* t4: -> NEG block       */
        LUAC_ABC(LUAC_OP_LE,   1, A, A + 1),        /* t5 POS: idx <= limit   */
        LUAC_AsBx(LUAC_OP_JMP, 0, 0),               /* t6: -> MOVE (true)     */
        LUAC_AsBx(LUAC_OP_JMP, 0, 0),               /* t7: -> EXIT (false)    */
        LUAC_ABC(LUAC_OP_LE,   1, A + 1, A),        /* t8 NEG: limit <= idx   */
        LUAC_AsBx(LUAC_OP_JMP, 0, 0),               /* t9: -> MOVE (true)     */
        LUAC_AsBx(LUAC_OP_JMP, 0, 0),               /* t10: -> EXIT (false)   */
        LUAC_ABC(LUAC_OP_MOVE, A + 3, A, 0),        /* t11 MOVE: R(A+3)=idx   */
        /* t12 (回循环体 JMP) 单独在下面补，保持 11 条 tail + FORPREP 1 条对称 */
    };
    /* 实际 fl 后需要 12 条：上面 11 条 + 最后的回循环体 JMP */
    unsigned int jmp_body = LUAC_AsBx(LUAC_OP_JMP, 0, 0);
    const int n_fl = 12;

    /* FORPREP 原地改 SUB，其后插 1 条 JMP(占位) */
    unsigned int fp_tail[1] = { LUAC_AsBx(LUAC_OP_JMP, 0, 0) };
    const int n_fp = 1;

    int pos_fp = fp0 + 1, pos_fl = fl0 + 1;

    /* 按物理位置降序: 先处理靠后锚点, 其插入不会移动靠前锚点 */
    if (fp0 > fl0) {
        p->code[fp0] = LUAC_ABC(LUAC_OP_SUB, A, A, A + 2);
        obf_code_insert(p, pos_fp + 1, fp_tail, n_fp);
        p->code[fl0] = LUAC_ABC(LUAC_OP_ADD, A, A, A + 2);
        obf_code_insert(p, pos_fl + 1, fl_tail, 11);
        obf_code_insert(p, pos_fl + 1 + 11, &jmp_body, 1);
    } else {
        p->code[fl0] = LUAC_ABC(LUAC_OP_ADD, A, A, A + 2);
        obf_code_insert(p, pos_fl + 1, fl_tail, 11);
        obf_code_insert(p, pos_fl + 1 + 11, &jmp_body, 1);
        p->code[fp0] = LUAC_ABC(LUAC_OP_SUB, A, A, A + 2);
        obf_code_insert(p, pos_fp + 1, fp_tail, n_fp);
    }

    /* 统一位移: 原始位置 x 在两次插入后的最终位置 */
    #define FLU_SHIFT(x) ((x) + (((x) >= pos_fp) ? n_fp : 0) + (((x) >= pos_fl) ? n_fl : 0))

    int sub_p  = FLU_SHIFT(fp0);
    int jfp_p  = sub_p + 1;
    int add_p  = FLU_SHIFT(fl0);
    /* fl 后各条相对 add_p 的偏移：t1=add+1 ... t12=add+12 */
    int t4_neg  = add_p + 4;    /* JMP -> NEG (t8) */
    int t5_pos  = add_p + 5;
    int t6_true = add_p + 6;    /* -> MOVE (t11) */
    int t7_exit = add_p + 7;    /* -> EXIT */
    int t8_neg  = add_p + 8;
    int t9_true = add_p + 9;    /* -> MOVE (t11) */
    int t10_exit= add_p + 10;   /* -> EXIT */
    int move_p  = add_p + 11;   /* MOVE R(A+3) */
    int jb_p    = add_p + 12;   /* JMP -> body */
    int exit_p  = FLU_SHIFT(fl0 + 1);   /* 原 FORLOOP 物理下一条 = 退出路径 */
    int body_p  = FLU_SHIFT(t_body0);   /* 循环体目标最终位置 */

    p->code[jfp_p]   = LUAC_AsBx(LUAC_OP_JMP, 0, add_p - jfp_p - 1);
    p->code[t4_neg]  = LUAC_AsBx(LUAC_OP_JMP, 0, t8_neg - t4_neg - 1);
    p->code[t6_true] = LUAC_AsBx(LUAC_OP_JMP, 0, move_p - t6_true - 1);
    p->code[t7_exit] = LUAC_AsBx(LUAC_OP_JMP, 0, exit_p - t7_exit - 1);
    p->code[t9_true] = LUAC_AsBx(LUAC_OP_JMP, 0, move_p - t9_true - 1);
    p->code[t10_exit]= LUAC_AsBx(LUAC_OP_JMP, 0, exit_p - t10_exit - 1);
    p->code[jb_p]    = LUAC_AsBx(LUAC_OP_JMP, 0, body_p - jb_p - 1);

#if FOR_LOOP_UNROLL_DEBUG
    fprintf(stderr, "[unroll] fp=%d fl=%d A=%d T=%d add=%d body=%d exit=%d\n",
            fp0, fl0, A, T, add_p, body_p, exit_p);
#endif
    #undef FLU_SHIFT
    return n_fp + n_fl;
}

static int unroll_function(luac_Proto *p) {
    int changes = 0;
    if (!p->code || p->sizecode <= 0) return 0;

    /* 一个高位临时寄存器，高于函数内所有真实寄存器（含 A..A+3）；串行复用 */
    int T = p->maxstacksize;
    if (T < 5) T = 5;
    obf_ensure_stack(p, T + 1);

    int i = 0;
    while (i < p->sizecode) {
        unsigned int ins = p->code[i];
        if ((ins & 0x3F) == LUAC_OP_FORPREP) {
            int A = (ins >> 6) & 0xFF;
            int sbx = ((ins >> 14) & 0x3FFFF) - 131071;
            int forloop_pos = i + 1 + sbx;
            if (forloop_pos > i && forloop_pos < p->sizecode) {
                unsigned int fl = p->code[forloop_pos];
                if ((fl & 0x3F) == LUAC_OP_FORLOOP && ((fl >> 6) & 0xFF) == A) {
                    changes += unroll_one(p, i, forloop_pos, T);
                    /* FORPREP 原地变 SUB、其后插入 1 条 JMP，跳过它避免重复处理 */
                    i += 1 + 1;
                    continue;
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
