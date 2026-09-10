/*
** op48_junk.c - Inject invalid opcode (47-63) junk instructions
** andlua VM ignores these, so they don't affect execution.
*/
#include <time.h>
#include "obf_util.h"

static unsigned int make_op48(int multi) {
    int op = 48;
    if (multi) op = 54 + (int)(obf_rand() % 10); /* 54-63: undefined opcodes, VM ignores; 47-53 are luasafe extensions (SECTION/IS/TRY etc.) that WILL execute */
    int a = 127;
    int b = 256 + (int)(obf_rand() % 256);
    int c = (int)(obf_rand() % 201);
    return (unsigned int)op | ((unsigned int)a << 6) | ((unsigned int)c << 14) | ((unsigned int)b << 23);
}

static void inject_function(luac_Proto *p, int count, int multi) {
    if (!p->code) return;
    /* Insert at the very end of the function (after all instructions).
       Guarantees junk is unreachable regardless of control-flow
       transformations (flatten/cfg_shuffle may place reachable code
       after the last RETURN). */
    int insert_pos = p->sizecode;
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + count));
    for (int i = 0; i < count; i++) p->code[insert_pos + i] = make_op48(multi);
    p->sizecode += count;
    /* clear lineinfo to avoid mismatch */
    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;
    if (p->p) for (int i = 0; i < p->sizep; i++)
        inject_function(p->p[i], count > 10 ? count / 2 : 5, multi);
}

int op48_junk_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    int count = 50;
    int multi = 1;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
        lua_getfield(L, 2, "multi");
        if (lua_isboolean(L, -1)) multi = lua_toboolean(L, -1);
        lua_pop(L, 1);
    }
    inject_function(p, count, multi);
    lua_pushinteger(L, 1);
    return 1;
}
