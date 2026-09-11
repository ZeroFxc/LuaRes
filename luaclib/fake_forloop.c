/*
 * fake_forloop.c - 恶意伪造 FORPREP+FORLOOP 对
 *
 * 在安全位置插入伪造的数值 for 循环（FORPREP+FORLOOP 对），
 * 循环次数为 0（init > limit 且 step > 0），实际不执行循环体，
 * 但反编译器会识别为 for 循环并输出无意义的 for 结构。
 *
 * 反编译器依赖 FORPREP A + FORLOOP A（寄存器一致+配对跳转）识别数值 for，
 * 伪造的配对会让反编译输出大量无意义 for，干扰分析。
 *
 * 用小寄存器（< 几十），避免被反编译器视为混淆注入的假寄存器。
 * 实际使用高寄存器（old_max + offset），但 offset 控制在小范围内。
 *
 * 插入结构：
 *   LOADK  R(A),   init   (init = 1)
 *   LOADK  R(A+1), limit  (limit = 0, init > limit)
 *   LOADK  R(A+2), step   (step = 1)
 *   FORPREP A, +1  (跳转到 FORLOOP)
 *   [循环体 - 可以是垃圾指令或空]
 *   FORLOOP A, -2  (条件为假，fall-through)
 *
 * FORPREP 语义：R(A) -= R(A+2); pc += sBx (不检查条件)
 * FORLOOP 语义：R(A) += R(A+2); if step>0? idx<=limit : limit<=idx
 *                then R(A)=idx,R(A+3)=idx,pc+=sBx
 *
 * init=1, limit=0, step=1: FORLOOP 时 idx=1, 1<=0 为假，不执行循环体。
 */

#include "obf_util.h"

#define FAKE_FORLOOP_DEBUG 0

/* 判断位置是否安全插入 */
static int is_safe_insert(luac_Proto *p, int pos) {
    if (pos <= 0 || pos >= p->sizecode) return 0;

    int prev_op = p->code[pos - 1] & 0x3F;
    int cur_op = p->code[pos] & 0x3F;

    /* 不能在条件指令之后（下一条必须是 JMP） */
    if (prev_op == 31 || prev_op == 32 || prev_op == 33 ||
        prev_op == 34 || prev_op == 35) return 0;

    /* 不能在 LOADKX 之后（下一条必须是 EXTRAARG） */
    if (prev_op == 2) return 0;

    /* 不能在 SETLIST C=0 之后（下一条必须是 EXTRAARG） */
    if (prev_op == 43) {
        int c = (p->code[pos - 1] >> 14) & 0x1FF;
        if (c == 0) return 0;
    }

    /* 不能在 CLOSURE 之后（可能紧跟 upvalue 设置） */
    if (prev_op == 44) return 0;

    /* 不能在 JMP 之后（JMP之后通常是跳转目标，插入可能破坏跳转语义） */
    if (prev_op == 30) return 0;

    /* 不能在 LOADBOOL 之后（tforloop_as_jump插入LOADBOOL+TFORLOOP配对，插入会破坏） */
    if (prev_op == 3) return 0;

    /* 不能插入在 JMP/RETURN/TAILCALL 位置 */
    if (cur_op == 30 || cur_op == 38 || cur_op == 37) return 0;

    /* 不能插入在 EXTRAARG 位置 */
    if (cur_op == 46) return 0;

    /* 不能插入在 FORLOOP/FORPREP/TFORLOOP 位置 */
    if (cur_op == 39 || cur_op == 40 || cur_op == 42) return 0;

    return 1;
}

static int inject_fake_forloop(luac_Proto *p, int pos, int base_reg) {
    /* A = base_reg, A+1 = base_reg+1, A+2 = base_reg+2, A+3 = base_reg+3 */
    int A = base_reg;

    /* 确保有足够的常量 */
    int k_init = obf_add_k_number(p, 1.0);   /* init = 1 */
    int k_limit = obf_add_k_number(p, 0.0);  /* limit = 0 */
    int k_step = obf_add_k_number(p, 1.0);   /* step = 1 */

    /* 构造 6 条指令：
     * [0] LOADK  A,   k_init
     * [1] LOADK  A+1, k_limit
     * [2] LOADK  A+2, k_step
     * [3] FORPREP A, +1  (跳转到 [5])
     * [4] [垃圾指令 - 用 LOADNIL A+3, A+3 作为循环体占位]
     * [5] FORLOOP A, -2  (条件为假，fall-through)
     */
    unsigned int ins[6];
    ins[0] = LUAC_ABx(1, A, k_init);           /* LOADK */
    ins[1] = LUAC_ABx(1, A + 1, k_limit);      /* LOADK */
    ins[2] = LUAC_ABx(1, A + 2, k_step);       /* LOADK */
    ins[3] = LUAC_AsBx(40, A, 1);              /* FORPREP A, +1 (跳转到 ins[5]) */
    ins[4] = LUAC_ABC(4, A + 3, 0, 0);         /* LOADNIL R(A+3) only: B is count-1, must be 0 */
    ins[5] = LUAC_AsBx(39, A, -2);             /* FORLOOP A, -2 (跳回 ins[4]) */

    /* 插入到 pos 位置（1-based） */
    obf_code_insert(p, pos + 1, ins, 6);

#if FAKE_FORLOOP_DEBUG
    fprintf(stderr, "[fake_forloop] injected at pos=%d A=%d\n", pos, A);
#endif

    return 1;
}

static int process_function(lua_State *L, luac_Proto *p, int count) {
    int changes = 0;
    int old_max = p->maxstacksize;
    int base_reg = old_max;  /* 用 old_max 开始的寄存器 */

    /* 扩展 maxstacksize，需要 4 个寄存器 (A, A+1, A+2, A+3) */
    if (base_reg + 4 > 250) return 0; /* need 4 scratch regs strictly above used range; skip if no room */
    obf_ensure_stack(p, base_reg + 4);

    int i = 0;
    int injected = 0;
    while (i < p->sizecode && injected < count) {
        if (is_safe_insert(p, i)) {
            if (inject_fake_forloop(p, i, base_reg)) {
                changes++;
                injected++;
                i += 15;  /* 跳过插入的6条+间隔9条，避免与cfg_shuffle重排后的紧密指令对冲突 */
                continue;
            }
        }
        i++;
    }

    return changes;
}

int fake_forloop_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int count = 10;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }

    int n = process_function(L, p, count);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        n += process_function(L, p->p[i], 10);  /* sub-proto fake loops */

    lua_pushinteger(L, n);
    return 1;
}
