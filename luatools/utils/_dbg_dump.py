path = r'E:\LuaRes\luaclib\luac.c'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

old = '''static int luac_dump(lua_State *L) {
    luac_Proto *f = (luac_Proto *)luaL_checkudata(L, 1, "luac.Proto");

    /* sync all Lua tables back to C */
    sync_all_tables(L, f);

    g_null_src = g_empty_src = g_other_src = 0;
    count_source(f);
#if LUACLIB_DEBUG
    fprintf(stderr, "[dump debug] null_src=%d empty_src=%d other_src=%d\\n", g_null_src, g_empty_src, g_other_src);
#endif

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

new = '''static int luac_dump(lua_State *L) {
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

src = src.replace(old, new)
with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
print("debug added to luac_dump")
