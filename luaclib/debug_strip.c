/*
** debug_strip.c - Remove debug information (lineinfo, locvars, upvalue names)
*/
#include "obf_util.h"

static void strip_function(luac_Proto *p) {
    /* lineinfo: free and set NULL (dump checks sizelineinfo==0) */
    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;
    /* locvars: free names, set arrays NULL */
    if (p->locvar_name) {
        for (int i = 0; i < p->sizelocvars; i++) free(p->locvar_name[i]);
        free(p->locvar_name);
        p->locvar_name = NULL;
    }
    if (p->locvar_name_len) { free(p->locvar_name_len); p->locvar_name_len = NULL; }
    if (p->locvar_startpc) { free(p->locvar_startpc); p->locvar_startpc = NULL; }
    if (p->locvar_endpc) { free(p->locvar_endpc); p->locvar_endpc = NULL; }
    p->sizelocvars = 0;
    /* upvalue names: leave as-is (dump may access them; instack/idx needed for execution) */
    /* source: replace with empty string instead of NULL (dump may strlen it) */
    if (p->source) { free(p->source); }
    p->source = luac_strdup("");
    p->source_len = 0;
    p->linedefined = 0;
    p->lastlinedefined = 0;

    if (p->p) for (int i = 0; i < p->sizep; i++) strip_function(p->p[i]);
}

int debug_strip_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    strip_function(p);
    lua_pushinteger(L, 1);
    return 1;
}
