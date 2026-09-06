/*
** opaque_junk.c - Opaque predicate junk branch injection (C implementation)
** Pattern: LOADBOOL(true) + TEST(C=0) + JMP + [dead junk instructions]
** Standard Lua TEST A,C: if (l_isfalse(R(A)) ~= (C~=0)) then pc++
** With R(A)=true, C=0: isfalse(true)=0, (0~=0)=0, 0~=0=false -> don't skip -> JMP -> skip junk
*/
#include <time.h>
#include <stdlib.h>
#include "obf_util.h"

#define CONDITION_OPS(op) ((op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE||(op)==LUAC_OP_TEST||(op)==LUAC_OP_TESTSET)

static unsigned int make_junk_inst(int high_reg, int extra) {
    int r = obf_rand() % 5;
    int reg = high_reg + (obf_rand() % (extra > 0 ? extra : 1));
    if (r == 0) {
        return LUAC_ABC(LUAC_OP_MOVE, reg, reg, 0);
    } else if (r == 1) {
        return LUAC_ABC(LUAC_OP_LOADBOOL, reg, 0, 0);
    } else if (r == 2) {
        return LUAC_ABC(LUAC_OP_NEWTABLE, reg, 0, 0);
    } else if (r == 3) {
        return LUAC_ABC(LUAC_OP_LEN, reg, reg, 0);
    } else {
        return LUAC_ABC(LUAC_OP_MOVE, reg, reg, 0);
    }
}

static int inject_function(luac_Proto *p, int count) {
    if (!p->code || p->sizecode < 5 || count <= 0) return 0;

    int old_maxstack = p->maxstacksize;
    int extra = 10;
    if (old_maxstack + extra > 250) extra = 250 - old_maxstack;
    if (extra <= 0) extra = 1;
    int high_reg = old_maxstack;
    obf_ensure_stack(p, old_maxstack + extra);

    int injected = 0;
    int attempts = 0;
    while (injected < count && attempts < count * 20) {
        attempts++;
        int pos = 1 + obf_rand() % (p->sizecode - 1);
        if (pos > 0) {
            int prev_op = p->code[pos - 1] & 0x3F;
            if (CONDITION_OPS(prev_op)) continue;
        }

        int junk_size = 3 + obf_rand() % 6; /* 3-8 */
        int branch_len = 3 + junk_size; /* LOADBOOL + TEST + JMP + junk */

        /* build branch */
        unsigned int *branch = (unsigned int *)malloc(sizeof(unsigned int) * branch_len);
        int bi = 0;
        branch[bi++] = LUAC_ABC(LUAC_OP_LOADBOOL, high_reg, 1, 0); /* R(high)=true */
        /* This Lua's TEST: C=1 -> skip if isfalse(ra); true->not isfalse->don't skip->JMP */
        branch[bi++] = LUAC_ABC(LUAC_OP_TEST, high_reg, 0, 1);     /* C=1 with true: don't skip JMP */
        branch[bi++] = LUAC_AsBx(LUAC_OP_JMP, 0, junk_size);       /* skip junk_size instructions */
        for (int j = 0; j < junk_size; j++)
            branch[bi++] = make_junk_inst(high_reg, extra);

        /* insert branch at pos (0-based) */
        p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + branch_len));
        memmove(&p->code[pos + branch_len], &p->code[pos],
                sizeof(unsigned int) * (p->sizecode - pos));
        memcpy(&p->code[pos], branch, sizeof(unsigned int) * branch_len);
        p->sizecode += branch_len;

        /* adjust jumps: insertion at pos (0-based) = pos+1 (1-based), length branch_len */
        obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, branch_len);

        free(branch);
        injected++;
    }

    /* clear lineinfo */
    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;

    return injected;
}

int opaque_junk_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    obf_srand((unsigned int)time(NULL));

    int count = 10;
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
