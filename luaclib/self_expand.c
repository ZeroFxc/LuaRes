/* self_expand.c - SELF 展开
 *
 * 把 SELF A,B,C（方法调用）展开为 GETTABLE A,B,C + MOVE A+1,B。
 *
 * SELF 语义：R(A) = R(B)[RK(C)], R(A+1) = R(B)
 * 展开后：GETTABLE A, B, RK(C)  → R(A) = R(B)[RK(C)]
 *          MOVE A+1, B           → R(A+1) = R(B)
 *
 * 效果：方法调用的 SELF 指令消失，变成普通表访问+寄存器传递，
 * 反编译器难以识别方法调用模式。
 */
#include "obf_util.h"
#include <stdlib.h>
#include <string.h>

#ifndef SELFEXP_DEBUG
#define SELFEXP_DEBUG 0
#endif
#if SELFEXP_DEBUG
#define SDBG(...) fprintf(stderr, __VA_ARGS__)
#else
#define SDBG(...)
#endif

static int process_proto(luac_Proto *p) {
    if (!p->code || p->sizecode < 2) return 0;
    int n = p->sizecode;
    int changes = 0;

    /* 从后往前遍历，替换 SELF 为 GETTABLE + MOVE */
    for (int i = n - 1; i >= 0; i--) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        if (op != LUAC_OP_SELF) continue;

        int a = (ins >> 6) & 0xFF;
        int b = (ins >> 23) & 0x1FF;
        int c = (ins >> 14) & 0x1FF;

        SDBG("[selfexp] SELF at %d A=%d B=%d C=%d\n", i, a, b, c);

        /* GETTABLE A, B, C — R(A) = R(B)[RK(C)] */
        unsigned int gettable = LUAC_ABC(LUAC_OP_GETTABLE, a, b, c);
        /* MOVE A+1, B — R(A+1) = R(B) */
        unsigned int move = LUAC_ABC(LUAC_OP_MOVE, a + 1, b, 0);

        /* 替换：SELF → GETTABLE + MOVE（插入一条） */
        unsigned int *new_code = (unsigned int *)malloc(sizeof(unsigned int) * (n + 1));
        memcpy(new_code, p->code, sizeof(unsigned int) * i);
        new_code[i] = gettable;
        new_code[i + 1] = move;
        memcpy(new_code + i + 2, p->code + i + 1, sizeof(unsigned int) * (n - i - 1));
        free(p->code);
        p->code = new_code;
        n += 1;
        p->sizecode = n;

        /* 修正 JMP 偏移：在位置 i+1 插入了 1 条 */
        obf_adjust_jumps_insert(p->code, n, i + 1, 1);

        /* 确保 maxstacksize 足够（SELF 用 A 和 A+1，展开后仍然用 A 和 A+1） */
        if (a + 2 > p->maxstacksize) {
            p->maxstacksize = (unsigned char)(a + 2);
        }

        changes++;
    }

    return changes;
}

static void process_recursive(luac_Proto *p, int *total) {
    if (p->p) {
        for (int i = 0; i < p->sizep; i++)
            process_recursive(p->p[i], total);
    }
    *total += process_proto(p);
}

int self_expand_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    luac_sync_proto(L, 1);
    obf_invalidate_all_caches(L, p);
    int total = 0;
    process_recursive(p, &total);
    lua_pushinteger(L, total);
    return 1;
}
