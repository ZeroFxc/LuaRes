/*
** antidec.c - Anti-decompiler protection
** Poison headers, strip lineinfo, inject junk source/upvalues/constants
** IMPORTANT: junk upvalues only in main function, never in sub-functions!
*/
#include <time.h>
#include "obf_util.h"

static char *junk_string(int len) {
    char *s = luac_alloc(len + 1);
    for (int i = 0; i < len; i++) s[i] = (char)(0x80 + (obf_rand() % 0x80));
    s[len] = '\0';
    return s;
}

static void poison_header(luac_Proto *p, int is_main) {
    if (is_main) {
        if (p->maxstacksize < 250) p->maxstacksize = 250;
        p->numparams = 255;
        p->is_vararg = 2; /* valid: vararg + needs arg */
        p->linedefined = (int)0xDEADBEEF;
        p->lastlinedefined = -1;
    } else {
        if (p->maxstacksize < 2) p->maxstacksize = 2;
    }
    if (p->p) for (int i = 0; i < p->sizep; i++) poison_header(p->p[i], 0);
}

static void strip_lineinfo(luac_Proto *p) {
    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;
    if (p->locvar_name) {
        for (int i = 0; i < p->sizelocvars; i++) free(p->locvar_name[i]);
        free(p->locvar_name); p->locvar_name = NULL;
    }
    if (p->locvar_name_len) { free(p->locvar_name_len); p->locvar_name_len = NULL; }
    if (p->locvar_startpc) { free(p->locvar_startpc); p->locvar_startpc = NULL; }
    if (p->locvar_endpc) { free(p->locvar_endpc); p->locvar_endpc = NULL; }
    p->sizelocvars = 0;
    if (p->p) for (int i = 0; i < p->sizep; i++) strip_lineinfo(p->p[i]);
}

static void inject_junk_source(luac_Proto *p, int is_main) {
    if (is_main) {
        if (p->source) free(p->source);
        p->source = junk_string(200);
        p->source_len = 200;
    }
    if (p->p) for (int i = 0; i < p->sizep; i++) inject_junk_source(p->p[i], 0);
}

/* Only for main! Sub-functions must keep real upvalues or CLOSURE breaks. */
static void inject_junk_upvalues(luac_Proto *p, int is_main) {
    if (is_main) {
        int junk_count = 20 + (int)(obf_rand() % 31); /* 20-50 */
        p->upval_instack = realloc(p->upval_instack, sizeof(unsigned char) * junk_count);
        p->upval_idx = realloc(p->upval_idx, sizeof(unsigned char) * junk_count);
        p->upval_name = realloc(p->upval_name, sizeof(char *) * junk_count);
        p->upval_name_len = realloc(p->upval_name_len, sizeof(int) * junk_count);
        for (int i = 0; i < junk_count; i++) {
            p->upval_instack[i] = 0; /* closed upvalue, never touches stack */
            p->upval_idx[i] = (unsigned char)(obf_rand() % 256);
            int name_len = 5 + (int)(obf_rand() % 16);
            p->upval_name[i] = junk_string(name_len);
            p->upval_name_len[i] = name_len;
        }
        p->sizeupvalues = junk_count;
    }
    if (p->p) for (int i = 0; i < p->sizep; i++) inject_junk_upvalues(p->p[i], 0);
}

static void inject_junk_constants(luac_Proto *p, int is_main) {
    if (is_main) {
        char *j1 = junk_string(50);
        obf_add_k_string(p, j1, 50);
        free(j1);
        char *j2 = junk_string(30);
        obf_add_k_string(p, j2, 30);
        free(j2);
        obf_add_k_number(p, (double)0xDEADBEEF);
        obf_add_k_number(p, -(double)0xCAFEBABE);
    }
    if (p->p) for (int i = 0; i < p->sizep; i++) inject_junk_constants(p->p[i], 0);
}

int antidec_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    int do_header = 1, do_strip = 1, do_source = 1, do_upvalues = 1, do_constants = 0;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "poison_header"); if (lua_isboolean(L, -1)) do_header = lua_toboolean(L, -1); lua_pop(L, 1);
        lua_getfield(L, 2, "strip_lineinfo"); if (lua_isboolean(L, -1)) do_strip = lua_toboolean(L, -1); lua_pop(L, 1);
        lua_getfield(L, 2, "junk_source"); if (lua_isboolean(L, -1)) do_source = lua_toboolean(L, -1); lua_pop(L, 1);
        lua_getfield(L, 2, "junk_upvalues"); if (lua_isboolean(L, -1)) do_upvalues = lua_toboolean(L, -1); lua_pop(L, 1);
        lua_getfield(L, 2, "junk_constants"); if (lua_isboolean(L, -1)) do_constants = lua_toboolean(L, -1); lua_pop(L, 1);
    }
    if (do_header) poison_header(p, 1);
    if (do_strip) strip_lineinfo(p);
    if (do_source) inject_junk_source(p, 1);
    if (do_upvalues) inject_junk_upvalues(p, 1);
    if (do_constants) inject_junk_constants(p, 1);
    lua_pushinteger(L, 1);
    return 1;
}
