/*
** opaque_predicate.c - Multi-pattern opaque predicate with dead code blocks
**
** 8 patterns (random):
**  0: LOADK 0 + LOADK 0 + LT(0<0=false) + JMP + dead   (always-false)
**  1: LOADK N + MUL(r,r) + LT(r<0=false) + JMP + dead  (always-false, x*x<0)
**  2: LOADK N + BXOR(r,r) + EQ(r==0=true) + JMP(dead)  (always-true, x^x==0)
**  3: LOADK N + BAND(r,r) + EQ(r==r=true) + JMP(dead)  (always-true, x&x==x)
**  4: LOADK N + BNOT+BNOT + EQ(r==r=true) + JMP(dead)  (always-true, ~~x==x)
**  5: LOADK N + ADD(r,1) + LT(r<r+1=true) + JMP(dead)  (always-true, x<x+1)
**  6: LOADK N + IDIV(r,1) + EQ(r==r=true) + JMP(dead)  (always-true, x//1==x)
**  7: LOADK N + MUL(r,r) + LE(0<=r=true) + JMP(dead)   (always-true, 0<=x*x)
**
** Always-false patterns (0,1): JMP always taken → dead code skipped
** Always-true patterns (2-7): JMP never taken → JMP itself is dead
*/
#include <time.h>
#include "obf_util.h"

#define CONDITION_OPS(op) ((op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE||(op)==LUAC_OP_TEST||(op)==LUAC_OP_TESTSET||(op)==LUAC_OP_LOADKX||(op)==LUAC_OP_TFORCALL)

static unsigned int random_dead_insn(luac_Proto *p, int r1, int r2) {
    /* 生成看起来有意义的死指令，使用 scratch 寄存器和已有常量 */
    int r = obf_rand() % 12;
    int kc = (p->sizek > 0) ? (int)(obf_rand() % p->sizek) : 0;
    switch (r) {
        case 0: return LUAC_ABC(LUAC_OP_MOVE, r1, r2, 0);
        case 1: return LUAC_ABC(LUAC_OP_LOADBOOL, r1, obf_rand() % 2, 0);
        case 2: return LUAC_ABC(LUAC_OP_NEWTABLE, r1, 0, 0);
        case 3: return LUAC_ABC(LUAC_OP_LEN, r1, r2, 0);
        case 4: return LUAC_ABx(LUAC_OP_LOADK, r1, kc);
        case 5: return LUAC_ABC(LUAC_OP_ADD, r1, r2, r2);
        case 6: return LUAC_ABC(LUAC_OP_SUB, r1, r2, r2);
        case 7: return LUAC_ABC(LUAC_OP_MUL, r1, r2, r2);
        case 8: return LUAC_ABC(LUAC_OP_BXOR, r1, r2, r2);
        case 9: return LUAC_ABC(LUAC_OP_BAND, r1, r2, r2);
        case 10: return LUAC_ABC(LUAC_OP_BOR, r1, r2, r2);
        default: return LUAC_ABC(LUAC_OP_UNM, r1, r2, 0);
    }
}

static int get_num_const(luac_Proto *p, double val) {
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TNUMFLT || p->k_tag[i] == LUA_TNUMINT) && p->k_num[i] == val) return i;
    }
    return obf_add_k_number(p, val);
}

/* 在指定位置插入不透明谓词块，返回插入长度 */
static int insert_predicate_at(luac_Proto *p, int pos) {
    int r1 = p->maxstacksize;
    int r2 = p->maxstacksize + 1;
    obf_ensure_stack(p, r2 + 1);

    int pattern = obf_rand() % 8;
    int zero_idx = get_num_const(p, 0.0);
    int one_idx = get_num_const(p, 1.0);
    /* 随机一个非零整数作为谓词的"种子" */
    int seed_val = (int)(obf_rand() % 2000) - 1000;
    if (seed_val == 0) seed_val = 42;
    int seed_idx = get_num_const(p, (double)seed_val);

    int dead_len = 4 + (int)(obf_rand() % 10); /* 4-13 条死指令 */
    int prefix = 0;
    unsigned int prefix_buf[8];

    switch (pattern) {
        case 0: /* LOADK 0 + LOADK 0 + LT(0<0) + JMP */
            prefix_buf[prefix++] = LUAC_ABx(LUAC_OP_LOADK, r1, zero_idx);
            prefix_buf[prefix++] = LUAC_ABx(LUAC_OP_LOADK, r2, zero_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_LT, 0, r1, r2);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 1: /* LOADK N + MUL(r,r) + LT(r<0) + JMP */
            prefix_buf[prefix++] = LUAC_ABx(LUAC_OP_LOADK, r1, seed_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_MUL, r1, r1, r1);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_LT, 0, r1, zero_idx + LUAC_BITRK);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 2: /* LOADK N + BXOR(r,r) + EQ(r==0) + JMP(dead) */
            prefix_buf[prefix++] = LUAC_ABx(LUAC_OP_LOADK, r1, seed_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_BXOR, r1, r1, r1);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_EQ, 1, r1, zero_idx + LUAC_BITRK);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 3: /* LOADK N + BAND(r,r) + EQ(r==r) + JMP(dead) */
            prefix_buf[prefix++] = LUAC_ABx(LUAC_OP_LOADK, r1, seed_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_BAND, r1, r1, r1);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_EQ, 1, r1, r1);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 4: /* LOADK N + BNOT+BNOT + EQ(r==r) + JMP(dead) */
            prefix_buf[prefix++] = LUAC_ABx(LUAC_OP_LOADK, r1, seed_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_BNOT, r1, r1, 0);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_BNOT, r1, r1, 0);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_EQ, 1, r1, r1);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 5: /* LOADK N + ADD(r,1) + LT(r<r+1) + JMP(dead) */
            prefix_buf[prefix++] = LUAC_ABx(LUAC_OP_LOADK, r1, seed_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_ADD, r2, r1, one_idx + LUAC_BITRK);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_LT, 1, r1, r2);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 6: /* LOADK N + IDIV(r,1) + EQ(r==r) + JMP(dead) */
            prefix_buf[prefix++] = LUAC_ABx(LUAC_OP_LOADK, r1, seed_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_IDIV, r2, r1, one_idx + LUAC_BITRK);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_EQ, 1, r2, r1);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 7: /* LOADK N + MUL(r,r) + LE(0<=r) + JMP(dead) */
            prefix_buf[prefix++] = LUAC_ABx(LUAC_OP_LOADK, r1, seed_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_MUL, r1, r1, r1);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_LE, 1, zero_idx + LUAC_BITRK, r1);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
    }

    int insert_len = prefix + dead_len;
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + insert_len));
    memmove(&p->code[pos + insert_len], &p->code[pos],
            sizeof(unsigned int) * (p->sizecode - pos));
    memcpy(&p->code[pos], prefix_buf, sizeof(unsigned int) * prefix);
    for (int i = 0; i < dead_len; i++)
        p->code[pos + prefix + i] = random_dead_insn(p, r1, r2);
    p->sizecode += insert_len;

    /* 调整跳转：插入位置 pos (0-based) = pos+1 (1-based) */
    obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, insert_len);

    return insert_len;
}

static int is_safe_pos(luac_Proto *p, int pos) {
    if (pos <= 0 || pos >= p->sizecode) return 0;
    /* 不能在条件指令后插入（下一条必须是 JMP） */
    if (CONDITION_OPS(p->code[pos - 1] & 0x3F)) return 0;
    /* 不能在 JMP 目标位置插入（会破坏跳转） */
    /* 不能在 RETURN 后插入 */
    if ((p->code[pos] & 0x3F) == LUAC_OP_RETURN) return 0;
    if ((p->code[pos] & 0x3F) == LUAC_OP_EXTRAARG) return 0;
    return 1;
}

static void inject_function(luac_Proto *p, int count) {
    if (!p->code || p->sizecode < 4 || count <= 0) return;

    int injected = 0;
    int attempts = 0;
    while (injected < count && attempts < count * 15) {
        attempts++;
        int pos = 1 + (int)(obf_rand() % (p->sizecode - 2));
        if (!is_safe_pos(p, pos)) continue;
        insert_predicate_at(p, pos);
        injected++;
    }

    /* 函数头也插一个 */
    if (p->sizecode > 4) {
        insert_predicate_at(p, 0);
    }

    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;
}

int opaque_predicate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    obf_srand((unsigned int)time(NULL));

    int count = 8;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }

    inject_function(p, count);

    if (p->p) {
        for (int i = 0; i < p->sizep; i++) {
            inject_function(p->p[i], count > 4 ? count / 2 : 2);
        }
    }

    lua_pushinteger(L, 1);
    return 1;
}
