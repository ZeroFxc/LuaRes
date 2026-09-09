/*
** reg_shuffle.c - Register shuffle / redundant MOVE chain injection
** Injects MOVE save/restore chains at function start using existing registers.
** Does NOT increase maxstacksize — uses R1/R2 which are always valid.
*/
#include "obf_util.h"

static void inject_function(luac_Proto *p, int count) {
    if (!p->code || p->sizecode < 2 || count <= 0) return;
    if (p->is_vararg) return;
    if (p->maxstacksize < 4) return; /* need 3 high registers for swap-restore */

    /* Use the 3 highest registers as scratch — they are temporaries, never
       hold parameters or live values at function entry, so corrupting them
       is safe. Do a full swap(r0,r1) via r2, then swap back — net no-op. */
    int r0 = p->maxstacksize - 1;
    int r1 = p->maxstacksize - 2;
    int r2 = p->maxstacksize - 3;

    int chains = 2;
    if (chains > count) chains = count;
    int n = chains * 6;  /* 6 instructions per swap-restore chain */

    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + n));
    memmove(&p->code[n], &p->code[0], sizeof(unsigned int) * p->sizecode);

    int pos = 0;
    for (int ch = 0; ch < chains; ch++) {
        /* swap r0,r1 via r2 temp, then swap back = net identity */
        p->code[pos++] = LUAC_ABC(LUAC_OP_MOVE, r2, r0, 0);  /* r2 = r0 */
        p->code[pos++] = LUAC_ABC(LUAC_OP_MOVE, r0, r1, 0);  /* r0 = r1 */
        p->code[pos++] = LUAC_ABC(LUAC_OP_MOVE, r1, r2, 0);  /* r1 = old r0 */
        p->code[pos++] = LUAC_ABC(LUAC_OP_MOVE, r2, r0, 0);  /* r2 = old r1 */
        p->code[pos++] = LUAC_ABC(LUAC_OP_MOVE, r0, r1, 0);  /* r0 = old r0 */
        p->code[pos++] = LUAC_ABC(LUAC_OP_MOVE, r1, r2, 0);  /* r1 = old r1 */
    }

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
