p = r'E:\LuaRes\luaclib\obf_util.c'
s = open(p, encoding='utf-8').read()

# Fix line 181 - remove debug code
s = s.replace(
    '    if (!sub_raw) { /*OCS_DBG*/ fprintf(stderr,"[OCS] no sub_proto sizep=%d\\n",main_p->sizep); lua_settop(L, top); return 0; }',
    '    if (!sub_raw) { lua_settop(L, top); return 0; }'
)

# Fix line 188 - remove leftover debug code
s = s.replace(
    '        (void*)sub_raw, sub_raw->sizecode, sub_raw->sizep, sub_raw->maxstacksize);\n    main_p->p[0] = NULL;',
    '    main_p->p[0] = NULL;'
)

open(p, 'w', encoding='utf-8').write(s)
print('fixed obf_util.c')
