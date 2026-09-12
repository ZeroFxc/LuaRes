/* jmp_split.c - JMP 分裂混淆
 *
 * 把长距离 JMP 分裂为两段短 JMP：
 *   原 JMP → 中转 JMP → 真实目标
 *
 * 约束：
 * - 只处理 OP_JMP (30)，不处理 FORLOOP/FORPREP/TFORLOOP（有循环变量更新语义）
 * - 不处理条件指令（EQ/LT/LE/TEST/TESTSET）后面的 JMP，以及 LOADBOOL C=1 后面的 JMP
 *   （在这些 JMP 后面插入中转点会被条件 fall-through 误执行）
 * - 只分裂 |sbx| > 3 的跳转
 */
#include "obf_util.h"

#ifndef JSPLIT_DEBUG
#define JSPLIT_DEBUG 0
#endif
#if JSPLIT_DEBUG
#define JDBG(...) fprintf(stderr, __VA_ARGS__)
#else
#define JDBG(...)
#endif

static int is_cond_jmp_prev(int op) {
    return op == LUAC_OP_EQ || op == LUAC_OP_LT || op == LUAC_OP_LE ||
           op == LUAC_OP_TEST || op == LUAC_OP_TESTSET;
}

static int split_jmps_in_proto(luac_Proto *p) {
    if (!p->code || p->sizecode < 5) return 0;
    int changes = 0;

    for (int i = p->sizecode - 1; i >= 0; i--) {
        if ((p->code[i] & 0x3F) != LUAC_OP_JMP) continue;

        /* 跳过条件指令后面的 JMP */
        if (i > 0) {
            int prev_op = p->code[i-1] & 0x3F;
            if (is_cond_jmp_prev(prev_op)) continue;
            if (prev_op == LUAC_OP_LOADBOOL &&
                ((p->code[i-1] >> 14) & 0x1FF) == 1) continue;
        }

        int a = (p->code[i] >> 6) & 0xFF;
        int sbx = ((p->code[i] >> 14) & 0x3FFFF) - 131071;

        /* 只分裂距离 > 3 的跳转 */
        if (sbx >= -3 && sbx <= 3) continue;

        int target = i + 1 + sbx;
        int insert_pos = i + 1; /* 0-based，在 JMP 后面插入 */

        JDBG("[jsplit] pos=%d sbx=%d target=%d A=%d\n", i, sbx, target, a);

        /* 插入 1 条中转 JMP */
        p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + 1));
        memmove(&p->code[insert_pos + 1], &p->code[insert_pos],
                sizeof(unsigned int) * (p->sizecode - insert_pos));
        p->sizecode += 1;

        /* 先修正其他 JMP（此时原 JMP 还是旧值，中转点为 0） */
        obf_adjust_jumps_insert(p->code, p->sizecode, insert_pos + 1, 1);

        /* 原 JMP 改为跳到中转点（sbx=0 → 目标 = i+1 = insert_pos），保留 A */
        p->code[i] = LUAC_AsBx(LUAC_OP_JMP, a, 0);

        /* 中转点跳到真实目标：目标在插入点之后则+1，之前则不变 */
        int new_target = (target > insert_pos) ? target + 1 : target;
        int mid_sbx = new_target - insert_pos - 1;
        p->code[insert_pos] = LUAC_AsBx(LUAC_OP_JMP, 0, mid_sbx);

        changes++;
    }

    return changes;
}

static void process_recursive(luac_Proto *p, int *total) {
    if (p->p) for (int i = 0; i < p->sizep; i++)
        process_recursive(p->p[i], total);
    *total += split_jmps_in_proto(p);
}

int jmp_split_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    int total = 0;
    process_recursive(p, &total);
    lua_pushinteger(L, total);
    return 1;
}
