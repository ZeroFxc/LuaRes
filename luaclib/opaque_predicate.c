/*
** opaque_predicate.c - Insert opaque predicates with dead code blocks
** Pattern: LOADK r1,0 + LOADK r2,0 + LT 0,r1,r2 (always false) + JMP + dead code
*/
#include <time.h>
#include "obf_util.h"

static unsigned int random_insn(void) {
    /* exclude EXTRAARG(46): must follow LOADKX, orphaned one has garbage Ax
       exclude LOADKX(2): requires EXTRAARG as next instruction
       SETLIST(43) with C=0 also requires EXTRAARG, force C>=1 */
    int op = obf_rand() % 46; /* 0-45, excludes EXTRAARG(46) */
    if (op == LUAC_OP_LOADKX) op = LUAC_OP_LOADK; /* LOADKX needs EXTRAARG follower */
    int a = obf_rand() % 16;
    int b = obf_rand() % 16;
    int c = obf_rand() % 16;
    if (op == LUAC_OP_SETLIST && c == 0) c = 1; /* SETLIST C=0 needs EXTRAARG */
    if (op == LUAC_OP_RETURN || op == LUAC_OP_CALL || op == LUAC_OP_TAILCALL) op = LUAC_OP_MOVE;
    if (op == LUAC_OP_JMP) return LUAC_AsBx(LUAC_OP_JMP, 0, 1 + (int)(obf_rand() % 5));
    if (op == LUAC_OP_LOADK) return LUAC_ABx(LUAC_OP_LOADK, a, (int)(obf_rand() % 6));
    return LUAC_ABC(op, a, b, c);
}

static int get_zero_const(luac_Proto *p) {
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TNUMFLT || p->k_tag[i] == LUA_TNUMINT) && p->k_num[i] == 0.0) return i;
    }
    return obf_add_k_number(p, 0.0);
}

static void add_opaque_block(luac_Proto *p) {
    if (!p->code || p->sizecode <= 2) return;
    int zero_idx = get_zero_const(p);
    int r1 = p->maxstacksize;
    int r2 = p->maxstacksize + 1;
    int dead_len = 5 + (int)(obf_rand() % 11); /* 5-15 */
    int prefix = 4; /* LOADK + LOADK + LT + JMP */
    int new_len = prefix + dead_len + p->sizecode;

    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * new_len);
    int ni = 0;
    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, r1, zero_idx);
    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, r2, zero_idx);
    new_code[ni++] = LUAC_ABC(LUAC_OP_LT, 0, r1, r2); /* A=0: skip if B<C false; 0<0 false -> never skip */
    new_code[ni++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
    for (int i = 0; i < dead_len; i++) new_code[ni++] = random_insn();
    memcpy(&new_code[ni], p->code, sizeof(unsigned int) * p->sizecode);
    ni += p->sizecode;

    /* Insertion is at function head (offset 0): every jump and its target
       shift by the same amount, so relative sBx in original code is unchanged.
       The only JMP in the opaque block is hardcoded (sBx=dead_len). No adjustment needed. */

    free(p->code);
    p->code = new_code;
    p->sizecode = ni;
    obf_ensure_stack(p, r2 + 1);
}

int opaque_predicate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    obf_srand((unsigned int)time(NULL));
    add_opaque_block(p);
    if (p->p) for (int i = 0; i < p->sizep; i++) {
        if (p->p[i]->sizecode > 4) add_opaque_block(p->p[i]);
    }
    lua_pushinteger(L, 1);
    return 1;
}
