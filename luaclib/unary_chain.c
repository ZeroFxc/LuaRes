/* unary_chain.c - 成对一元运算
 *
 * 在算术/位运算指令前插入成对的 UNM 运算（两次抵消），
 * 然后用临时寄存器替代原指令的 B 操作数。
 *
 * UNM tmp,B; UNM tmp,tmp → tmp = -(-B) = B
 *
 * 效果：数据流中出现"取反再取反"的死代码，寄存器分配被打乱。
 */
#include "obf_util.h"
#include <stdlib.h>
#include <string.h>

#ifndef UNARY_DEBUG
#define UNARY_DEBUG 0
#endif
#if UNARY_DEBUG
#define UDBG(...) fprintf(stderr, __VA_ARGS__)
#else
#define UDBG(...)
#endif

static int can_insert_before(unsigned int *code, int pos) {
    if (pos <= 0) return 0;
    int prev_op = code[pos - 1] & 0x3F;
    if (prev_op == LUAC_OP_EQ || prev_op == LUAC_OP_LT || prev_op == LUAC_OP_LE ||
        prev_op == LUAC_OP_TEST || prev_op == LUAC_OP_TESTSET ||
        prev_op == LUAC_OP_TFORCALL) return 0;
    if (prev_op == LUAC_OP_CLOSURE) return 0;
    if (prev_op == LUAC_OP_LOADKX) return 0;
    if (prev_op == LUAC_OP_SETLIST) {
        int c = (code[pos - 1] >> 14) & 0x1FF;
        if (c == 0) return 0;
    }
    return 1;
}

static int is_arith_op(int op) {
    return op == LUAC_OP_ADD || op == LUAC_OP_SUB ||
           op == LUAC_OP_MUL || op == LUAC_OP_MOD ||
           op == LUAC_OP_POW || op == LUAC_OP_DIV ||
           op == LUAC_OP_IDIV || op == LUAC_OP_BAND ||
           op == LUAC_OP_BOR || op == LUAC_OP_BXOR ||
           op == LUAC_OP_SHL || op == LUAC_OP_SHR;
}

static int process_proto(luac_Proto *p) {
    if (!p->code || p->sizecode < 3) return 0;
    int n = p->sizecode;
    int tmp_reg = p->maxstacksize;

    /* 第一遍：标记需要插入的位置 */
    int *inject = (int *)calloc(n, sizeof(int));
    int count = 0;
    for (int i = 1; i < n; i++) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int b = (ins >> 23) & 0x1FF;
        if (b >= 256 || b >= p->maxstacksize) continue;
        if (!is_arith_op(op)) continue;
        if (!can_insert_before(p->code, i)) continue;
        /* use the seedable shared PRNG; libc rand() ignored luac.srand and made
           fixed-seed output nondeterministic */
        if ((obf_rand() % 100) >= 40) continue;
        inject[i] = 1;
        count++;
    }

    if (count == 0) { free(inject); return 0; }

    /* 第二遍：构建新代码 + pos_map */
    int new_n = n + count * 2;
    unsigned int *nc = (unsigned int *)malloc(sizeof(unsigned int) * new_n);
    int *pos_map = (int *)malloc(sizeof(int) * (n + 1)); /* old_pos -> new_pos */
    int ni = 0;

    for (int i = 0; i < n; i++) {
        pos_map[i] = ni;
        if (inject[i]) {
            unsigned int ins = p->code[i];
            int b = (ins >> 23) & 0x1FF;
            /* UNM tmp, B */
            nc[ni++] = LUAC_ABC(LUAC_OP_UNM, tmp_reg, b, 0);
            /* UNM tmp, tmp */
            nc[ni++] = LUAC_ABC(LUAC_OP_UNM, tmp_reg, tmp_reg, 0);
            /* 原指令，B 改成 tmp_reg */
            unsigned int new_ins = (ins & ~(0x1FFu << 23)) | ((unsigned)tmp_reg << 23);
            nc[ni++] = new_ins;
            UDBG("[unary] old_pos=%d -> new_pos=%d B=%d tmp=%d\n", i, pos_map[i], b, tmp_reg);
        } else {
            nc[ni++] = p->code[i];
        }
    }
    pos_map[n] = ni;

    free(p->code);
    p->code = nc;
    p->sizecode = ni;

    /* 第三遍：修正 JMP/FORLOOP/FORPREP/TFORLOOP 的 sBx */
    for (int i = 0; i < ni; i++) {
        int op = nc[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP ||
            op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) {
            int sbx = ((nc[i] >> 14) & 0x3FFFF) - 131071;
            int old_target = i + 1 + sbx; /* 这是新位置下的 target，需要反推旧位置 */
            /* 新位置 i 对应的旧位置：反向查找 pos_map */
            int old_i = -1;
            for (int j = 0; j <= n; j++) {
                if (pos_map[j] == i) { old_i = j; break; }
                if (pos_map[j] > i) { old_i = j - 1; break; }
            }
            if (old_i < 0) continue;
            /* 旧 target = old_i + 1 + sbx（原始 sbx） */
            int old_target_orig = old_i + 1 + sbx;
            if (old_target_orig < 0 || old_target_orig > n) continue;
            int new_target = pos_map[old_target_orig];
            int new_sbx = new_target - i - 1;
            nc[i] = (nc[i] & 0x3FFF) | ((unsigned)(new_sbx + 131071) << 14);
        }
    }

    free(pos_map);
    free(inject);

    p->maxstacksize = (unsigned char)(tmp_reg + 1);
    return count;
}

static void process_recursive(luac_Proto *p, int *total) {
    if (p->p) {
        for (int i = 0; i < p->sizep; i++)
            process_recursive(p->p[i], total);
    }
    *total += process_proto(p);
}

int unary_chain_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    luac_sync_proto(L, 1);
    obf_invalidate_all_caches(L, p);
    srand(0x12345678);
    int total = 0;
    process_recursive(p, &total);
    lua_pushinteger(L, total);
    return 1;
}
