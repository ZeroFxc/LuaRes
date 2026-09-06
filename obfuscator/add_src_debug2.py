with open(r'E:\LuaRes\luaclib\luac.c', 'r', encoding='utf-8') as f:
    content = f.read()

# 在 luac_dump 前加静态计数函数
old1 = """static int luac_dump(lua_State *L) {"""
new1 = """static int g_null_src, g_empty_src, g_other_src;
static void count_source(luac_Proto *pp) {
    if (!pp->source) g_null_src++;
    else if (pp->source[0] == 0) g_empty_src++;
    else g_other_src++;
    for (int i = 0; i < pp->sizep; i++) count_source(pp->p[i]);
}

static int luac_dump(lua_State *L) {"""
content = content.replace(old1, new1, 1)

# 在 sync_all_tables 后加调用
old2 = """    /* sync all Lua tables back to C */
    sync_all_tables(L, f);

    DumpState D;"""
new2 = """    /* sync all Lua tables back to C */
    sync_all_tables(L, f);

    g_null_src = g_empty_src = g_other_src = 0;
    count_source(f);
    fprintf(stderr, "[dump debug] null_src=%d empty_src=%d other_src=%d\\n", g_null_src, g_empty_src, g_other_src);

    DumpState D;"""
content = content.replace(old2, new2, 1)

with open(r'E:\LuaRes\luaclib\luac.c', 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
