/*
** junk_move.c - Inject junk MOVE instructions between high registers
*/
#include <time.h>
#include "obf_util.h"

#define CONDITION_OPS(op) ((op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE||(op)==LUAC_OP_TEST||(op)==LUAC_OP_TESTSET)

static void inject_function(luac_Proto *p, int count) {
    if (!p->code || p->sizecode < 2 || count <= 0) return;
    int old_maxstack = p->maxstacksize;
    int extra = count < 20 ? count : 20;
    int new_max = old_maxstack + extra; if (new_max > 250) new_max = 250;
    p->maxstacksize = (unsigned char)new_max;
    int usable = new_max - old_maxstack; if (usable <= 0) usable = 1;

    int injected = 0, attempts = 0;
    while (injected < count && attempts < count * 10) {
        attempts++;
        int pos = 1 + (int)(obf_rand() % (p->sizecode - 1));
        if (CONDITION_OPS(p->code[pos-1] & 0x3F)) continue;
        int a = old_maxstack + (int)(obf_rand() % usable);
        int b = old_maxstack + (int)(obf_rand() % usable);
        p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + 1));
        memmove(&p->code[pos+1], &p->code[pos], sizeof(unsigned int) * (p->sizecode - pos));
        p->code[pos] = LUAC_ABC(LUAC_OP_MOVE, a, b, 0);
        p->sizecode++;
        obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, 1);
        injected++;
    }
    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;
    if (p->p) for (int i = 0; i < p->sizep; i++)
        inject_function(p->p[i], count > 10 ? count / 2 : 5);
}

int junk_move_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    obf_srand((unsigned int)time(NULL));
    int count = 50;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }
    inject_function(p, count);
    lua_pushinteger(L, 1);
    return 1;
}
