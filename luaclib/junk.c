/*
** junk.c - Safe junk code injection
**
** Injects harmless MOVE self-move instructions at function start.
** Uses existing registers (R1/R2) — no maxstacksize increase needed.
** MOVE r,r is a guaranteed no-op on any register value.
*/
#include "obf_util.h"

static void inject_function(luac_Proto *p, int count) {
    if (!p->code || p->sizecode < 2 || count <= 0) return;
    if (p->is_vararg) return;
    if (p->maxstacksize < 3) return;

    /* deterministic: 3 MOVE self-move instructions at function start */
    int n = 3;
    if (n > count) n = count;

    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + n));
    memmove(&p->code[n], &p->code[0], sizeof(unsigned int) * p->sizecode);

    p->code[0] = LUAC_ABC(LUAC_OP_MOVE, 1, 1, 0); /* MOVE R1, R1 */
    p->code[1] = LUAC_ABC(LUAC_OP_MOVE, 2, 2, 0); /* MOVE R2, R2 */
    p->code[2] = LUAC_ABC(LUAC_OP_MOVE, 1, 1, 0); /* MOVE R1, R1 */

    p->sizecode += n;

    /* lineinfo preserved — freeing causes use-after-free in bytecode loader */
}

int junk_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int count = 30;
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
