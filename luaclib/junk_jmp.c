/*
** junk_jmp.c - Inject no-op JMP (sBx=0) instructions at safe positions
*/
#include <time.h>
#include "obf_util.h"

#define CONDITION_OPS(op) ((op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE||(op)==LUAC_OP_TEST||(op)==LUAC_OP_TESTSET)

static int is_safe_pos(luac_Proto *p, int pos) {
    if (pos <= 0 || pos >= p->sizecode) return 0;
    /* cannot inject after condition ops (next must be JMP) */
    if (CONDITION_OPS(p->code[pos-1] & 0x3F)) return 0;
    /* cannot inject at JMP */
    if ((p->code[pos] & 0x3F) == LUAC_OP_JMP) return 0;
    return 1;
}

static int inject_function(luac_Proto *p, int count) {
    if (!p->code || p->sizecode < 2) return 0;
    int injected = 0;
    int attempts = 0;
    while (injected < count && attempts < count * 10) {
        attempts++;
        int pos = 1 + (int)(obf_rand() % (p->sizecode - 1));
        if (!is_safe_pos(p, pos)) continue;
        /* insert JMP sBx=0 at pos */
        p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + 1));
        memmove(&p->code[pos+1], &p->code[pos], sizeof(unsigned int) * (p->sizecode - pos));
        p->code[pos] = LUAC_AsBx(LUAC_OP_JMP, 0, 0);
        p->sizecode++;
        obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, 1);
        injected++;
    }
    if (p->p) for (int i = 0; i < p->sizep; i++) injected += inject_function(p->p[i], count);
    return injected;
}

int junk_jmp_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    obf_srand((unsigned int)time(NULL));
    int count = 50;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }
    int n = inject_function(p, count);
    lua_pushinteger(L, n);
    return 1;
}
