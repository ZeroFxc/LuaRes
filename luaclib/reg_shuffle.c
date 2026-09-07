/*
** reg_shuffle.c - Register shuffle / redundant MOVE chain injection
** Injects MOVE save/restore chains at function start using existing registers.
** Does NOT increase maxstacksize — uses R1/R2 which are always valid.
*/
#include "obf_util.h"

static void inject_function(luac_Proto *p, int count) {
    if (!p->code || p->sizecode < 2 || count <= 0) return;
    if (p->is_vararg) return;
    if (p->maxstacksize < 3) return; /* need at least R0,R1,R2 */

    /* deterministic: 2 MOVE save/restore chains using R1 and R2 */
    int chains = 2;
    if (chains > count) chains = count;
    int n = chains * 2;

    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + n));
    memmove(&p->code[n], &p->code[0], sizeof(unsigned int) * p->sizecode);

    /* chain 0: MOVE R2, R1; MOVE R1, R2 — swap and restore R1/R2 */
    p->code[0] = LUAC_ABC(LUAC_OP_MOVE, 2, 1, 0);
    p->code[1] = LUAC_ABC(LUAC_OP_MOVE, 1, 2, 0);
    /* chain 1: MOVE R2, R1; MOVE R1, R2 — repeat */
    p->code[2] = LUAC_ABC(LUAC_OP_MOVE, 2, 1, 0);
    p->code[3] = LUAC_ABC(LUAC_OP_MOVE, 1, 2, 0);

    p->sizecode += n;

    /* lineinfo preserved */
}

int reg_shuffle_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int count = 20;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }

    inject_function(p, count);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        inject_function(p->p[i], count > 5 ? count / 2 : 5);

    lua_pushinteger(L, 1);
    return 1;
}
