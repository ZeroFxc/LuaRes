path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

old = '''void obf_invalidate_all_caches(lua_State *L, luac_Proto *p) {
    unref_table(L, &p->code_tbl);
    unref_table(L, &p->k_tbl);
    unref_table(L, &p->p_tbl);
    unref_table(L, &p->lineinfo_tbl);
    unref_table(L, &p->locvars_tbl);
    unref_table(L, &p->upvalues_tbl);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        obf_invalidate_all_caches(L, p->p[i]);
}'''

new = '''void obf_invalidate_all_caches(lua_State *L, luac_Proto *p) {
    fprintf(stderr, "[inv] p=%p sizek=%d sizecode=%d sizep=%d code=%p k_tag=%p p=%p\\n",
        (void*)p, p->sizek, p->sizecode, p->sizep, (void*)p->code, (void*)p->k_tag, (void*)p->p);
    fflush(stderr);
    unref_table(L, &p->code_tbl);
    unref_table(L, &p->k_tbl);
    unref_table(L, &p->p_tbl);
    unref_table(L, &p->lineinfo_tbl);
    unref_table(L, &p->locvars_tbl);
    unref_table(L, &p->upvalues_tbl);
    if (p->p) for (int i = 0; i < p->sizep; i++) {
        fprintf(stderr, "[inv] recurse %d: p->p[%d]=%p\\n", i, i, (void*)p->p[i]);
        fflush(stderr);
        obf_invalidate_all_caches(L, p->p[i]);
    }
    fprintf(stderr, "[inv] done p=%p\\n", (void*)p);
    fflush(stderr);
}'''

src = src.replace(old, new)
with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
print("debug added to obf_invalidate_all_caches")
