with open(r'E:\LuaRes\luaclib\luac.c', 'r', encoding='utf-8') as f:
    content = f.read()

old = """    /* sync all Lua tables back to C */
    sync_all_tables(L, f);

    DumpState D;"""

new = """    /* sync all Lua tables back to C */
    sync_all_tables(L, f);

    /* debug: check source NULL */
    {
        int null_src = 0, empty_src = 0, other_src = 0;
        void check_src(luac_Proto *pp) {
            if (!pp->source) null_src++;
            else if (pp->source[0] == 0) empty_src++;
            else other_src++;
            for (int i = 0; i < pp->sizep; i++) check_src(pp->p[i]);
        }
        check_src(f);
        fprintf(stderr, "[dump debug] null_src=%d empty_src=%d other_src=%d\\n", null_src, empty_src, other_src);
    }

    DumpState D;"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luaclib\luac.c', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
