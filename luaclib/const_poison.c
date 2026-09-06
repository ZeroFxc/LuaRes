/*
** const_poison.c - Constant pool poisoning (inject illegal tag values)
*/
#include <time.h>
#include "obf_util.h"

static void add_poison_const(luac_Proto *p, int tag) {
    int idx = p->sizek;
    p->k_tag = realloc(p->k_tag, sizeof(int) * (p->sizek + 1));
    p->k_str = realloc(p->k_str, sizeof(char *) * (p->sizek + 1));
    p->k_str_len = realloc(p->k_str_len, sizeof(int) * (p->sizek + 1));
    p->k_num = realloc(p->k_num, sizeof(double) * (p->sizek + 1));
    p->k_bool = realloc(p->k_bool, sizeof(int) * (p->sizek + 1));
    p->k_tag[idx] = tag;
    p->k_str[idx] = NULL;
    p->k_str_len[idx] = 0;
    p->k_num[idx] = 0;
    p->k_bool[idx] = 0;
    p->sizek++;
}

static void poison_function(luac_Proto *p, int count, int min_tag, int max_tag) {
    for (int i = 0; i < count; i++) {
        int tag = min_tag + (int)(obf_rand() % (max_tag - min_tag + 1));
        add_poison_const(p, tag);
    }
    if (p->p) for (int i = 0; i < p->sizep; i++)
        poison_function(p->p[i], count > 3 ? count / 2 : 2, min_tag, max_tag);
}

int const_poison_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_srand((unsigned int)time(NULL));
    int count = 5, min_tag = 0x80, max_tag = 0xFF;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
        lua_getfield(L, 2, "min_tag");
        if (lua_isnumber(L, -1)) min_tag = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
        lua_getfield(L, 2, "max_tag");
        if (lua_isnumber(L, -1)) max_tag = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }
    poison_function(p, count, min_tag, max_tag);
    lua_pushinteger(L, 1);
    return 1;
}
