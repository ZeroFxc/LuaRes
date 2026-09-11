import os

# Fix 1: obf_util.c - remove p_tbl invalidation and debug fprintf
path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

old_inv = '''void obf_invalidate_all_caches(lua_State *L, luac_Proto *p) {
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

new_inv = '''void obf_invalidate_all_caches(lua_State *L, luac_Proto *p) {
    /* NOTE: do NOT invalidate p_tbl here. The p table holds references to
       sub-proto userdata. Invalidating it would allow those userdata to be
       GC'd, freeing their C arrays while p->p[] still points to them
       (dangling pointer). C modules recurse into p->p[] and need the
       sub-proto C structs to stay alive. */
    unref_table(L, &p->code_tbl);
    unref_table(L, &p->k_tbl);
    unref_table(L, &p->lineinfo_tbl);
    unref_table(L, &p->locvars_tbl);
    unref_table(L, &p->upvalues_tbl);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        obf_invalidate_all_caches(L, p->p[i]);
}'''

src = src.replace(old_inv, new_inv)
with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
print("obf_util.c fixed (p_tbl preserved, debug removed)")

# Fix 2: const_shuffle.c - remove debug fprintf
path = r'E:\LuaRes\luaclib\const_shuffle.c'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

old_cs = '''int const_shuffle_process(lua_State *L) {
    fprintf(stderr, "[cs] ENTER\\n"); fflush(stderr);
    luac_Proto *p = obf_check_proto(L);
    fprintf(stderr, "[cs] got proto sizek=%d sizecode=%d sizep=%d\\n", p->sizek, p->sizecode, p->sizep); fflush(stderr);
    fprintf(stderr, "[cs] k_tag=%p k_str=%p code=%p p=%p\\n", (void*)p->k_tag, (void*)p->k_str, (void*)p->code, (void*)p->p);
    obf_invalidate_all_caches(L, p);
    fflush(stderr);
    fprintf(stderr, "[cs] after inv call\\n"); fflush(stderr);
    obf_srand((unsigned int)time(NULL));
    fprintf(stderr, "[cs] after srand\\n"); fflush(stderr);
    shuffle_function(p);
    fprintf(stderr, "[cs] shuffle done\\n"); fflush(stderr);
    lua_pushinteger(L, 1);
    return 1;
}'''

new_cs = '''int const_shuffle_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    obf_srand((unsigned int)time(NULL));
    shuffle_function(p);
    lua_pushinteger(L, 1);
    return 1;
}'''

src = src.replace(old_cs, new_cs)
with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
print("const_shuffle.c debug removed")

# Fix 3: luac.c - remove debug fprintf from luac_dump
path = r'E:\LuaRes\luaclib\luac.c'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

old_dump = '''static int luac_dump(lua_State *L) {
    luac_Proto *f = (luac_Proto *)luaL_checkudata(L, 1, "luac.Proto");
    fprintf(stderr, "[dump] enter sizek=%d sizecode=%d sizep=%d\\n", f->sizek, f->sizecode, f->sizep); fflush(stderr);

    /* sync all Lua tables back to C */
    sync_all_tables(L, f);
    fprintf(stderr, "[dump] after sync\\n"); fflush(stderr);

    g_null_src = g_empty_src = g_other_src = 0;
    count_source(f);
    fprintf(stderr, "[dump] after count_source null=%d empty=%d other=%d\\n", g_null_src, g_empty_src, g_other_src); fflush(stderr);

    DumpState D;
    D.buf = NULL;
    D.pos = 0;
    D.cap = 0;
    DumpGrow(&D, 1024);
    fprintf(stderr, "[dump] after DumpGrow\\n"); fflush(stderr);

    DumpHeader(&D);
    DumpByte(&D, (unsigned char)f->sizeupvalues);
    fprintf(stderr, "[dump] after header, calling DumpFunction\\n"); fflush(stderr);
    DumpFunction(&D, f);
    fprintf(stderr, "[dump] after DumpFunction pos=%d\\n", D.pos); fflush(stderr);

    lua_pushlstring(L, (const char *)D.buf, D.pos);
    free(D.buf);
    return 1;
}'''

new_dump = '''static int luac_dump(lua_State *L) {
    luac_Proto *f = (luac_Proto *)luaL_checkudata(L, 1, "luac.Proto");

    /* sync all Lua tables back to C */
    sync_all_tables(L, f);

    g_null_src = g_empty_src = g_other_src = 0;
    count_source(f);

    DumpState D;
    D.buf = NULL;
    D.pos = 0;
    D.cap = 0;
    DumpGrow(&D, 1024);

    DumpHeader(&D);
    DumpByte(&D, (unsigned char)f->sizeupvalues);  /* main closure upvalue count */
    DumpFunction(&D, f);

    lua_pushlstring(L, (const char *)D.buf, D.pos);
    free(D.buf);
    return 1;
}'''

src = src.replace(old_dump, new_dump)
with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
print("luac.c debug removed")

print("all fixes applied")
