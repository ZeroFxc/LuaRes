p = r'E:\LuaRes\luaclib\obf_util.c'
s = open(p, encoding='utf-8').read()
marker = 'luac_Proto *obf_check_proto(lua_State *L) {'
addition = """/*===========================================================================
** Cache invalidation (cached Lua tables in registry must be invalidated
** whenever the underlying C arrays are modified)
**=========================================================================*/
static void unref_table(lua_State *L, int *ref) {
    if (*ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, *ref);
        *ref = LUA_NOREF;
    }
}

void obf_invalidate_code_cache(lua_State *L, luac_Proto *p) {
    unref_table(L, &p->code_tbl);
}

void obf_invalidate_all_caches(lua_State *L, luac_Proto *p) {
    unref_table(L, &p->code_tbl);
    unref_table(L, &p->k_tbl);
    unref_table(L, &p->p_tbl);
    unref_table(L, &p->lineinfo_tbl);
    unref_table(L, &p->locvars_tbl);
    unref_table(L, &p->upvalues_tbl);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        obf_invalidate_all_caches(L, p->p[i]);
}

""" + marker
s = s.replace(marker, addition, 1)
open(p, 'w', encoding='utf-8').write(s)
print('done')
