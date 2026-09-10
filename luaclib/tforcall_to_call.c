/*
 * tforcall_to_call.c - TFORCALL → CALL 无损转换
 *
 * TFORCALL A B C 语义：把 R(A),R(A+1),R(A+2) 复制到 R(A+3),R(A+4),R(A+5)，
 * 然后调用 R(A+3)(R(A+4),R(A+5))，返回值放在 R(A+3) 开始。
 * 等价于：MOVE R(A+3),R(A) + MOVE R(A+4),R(A+1) + MOVE R(A+5),R(A+2) + CALL R(A+3),3,C+1
 *
 * 反编译器用 TFORCALL+TFORLOOP 配对识别泛型 for 循环。
 * 把 TFORCALL 改成普通 CALL，TFORLOOP 保留，配对断裂，反编译器无法识别为迭代器循环。
 *
 * 注意：TFORLOOP 的 A 字段是 TFORCALL_A + 2，所以 TFORLOOP 检查 R(A+3)（第一个返回值）。
 * 转换后返回值仍然放在 R(A+3) 开始，TFORLOOP 能正确读取。
 */

#include "obf_util.h"

#define TFORCALL_TO_CALL_DEBUG 0

static int convert_one(luac_Proto *p, int pos) {
    unsigned int ins = p->code[pos];
    int op = ins & 0x3F;
    if (op != 41) return 0;  /* OP_TFORCALL */

    int A = (ins >> 6) & 0xFF;
    int C = (ins >> 14) & 0x1FF;
    /* B 字段在 TFORCALL 中被忽略（固定为 0） */

    /* 确保下一条是 TFORLOOP */
    if (pos + 1 >= p->sizecode) return 0;
    int next_op = p->code[pos + 1] & 0x3F;
    if (next_op != 42) return 0;  /* OP_TFORLOOP */

    /* 确保 TFORLOOP 的 A = A + 2 */
    int tfl_A = (p->code[pos + 1] >> 6) & 0xFF;
    if (tfl_A != A + 2) return 0;

    /* 确保 maxstacksize 足够（需要 R(A+5)） */
    int needed = A + 6;
    if (needed > p->maxstacksize) {
        obf_ensure_stack(p, needed);
    }

    /* 替换为 4 条指令：MOVE + MOVE + MOVE + CALL */
    unsigned int new_ins[4];
    new_ins[0] = LUAC_ABC(0, A + 3, A, 0);      /* MOVE R(A+3), R(A) */
    new_ins[1] = LUAC_ABC(0, A + 4, A + 1, 0);  /* MOVE R(A+4), R(A+1) */
    new_ins[2] = LUAC_ABC(0, A + 5, A + 2, 0);  /* MOVE R(A+5), R(A+2) */
    new_ins[3] = LUAC_ABC(36, A + 3, 3, C + 1); /* CALL R(A+3), 3, C+1 */

    /* 先替换当前指令，再插入 3 条 */
    p->code[pos] = new_ins[0];
    obf_code_insert(p, pos + 2, &new_ins[1], 3);

#if TFORCALL_TO_CALL_DEBUG
    fprintf(stderr, "[tforcall_to_call] pos=%d A=%d C=%d -> 4 ins\n", pos, A, C);
#endif

    return 1;
}

static int convert_function(luac_Proto *p) {
    int changes = 0;
    int i = 0;
    while (i < p->sizecode) {
        if ((p->code[i] & 0x3F) == 41) {  /* OP_TFORCALL */
            if (convert_one(p, i)) {
                changes++;
                i += 4;  /* 跳过新插入的 4 条指令 */
                continue;
            }
        }
        i++;
    }
    return changes;
}

int tforcall_to_call_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int n = convert_function(p);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        n += convert_function(p->p[i]);

    lua_pushinteger(L, n);
    return 1;
}
