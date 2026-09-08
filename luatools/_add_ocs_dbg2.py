p = r'E:\LuaRes\luaclib\obf_util.c'
s = open(p, encoding='utf-8').read()

old = '''    main_p->p[0] = NULL;
    main_p->sizep = 0;
    lua_settop(L, top);
    *out = sub_raw;
    return 1;
}'''

new = '''    fprintf(stderr,"[OCS] sub_raw=%p sizecode=%d sizep=%d maxstack=%d\\n",
        (void*)sub_raw, sub_raw->sizecode, sub_raw->sizep, sub_raw->maxstacksize);
    main_p->p[0] = NULL;
    main_p->sizep = 0;
    lua_settop(L, top);
    *out = sub_raw;
    fprintf(stderr,"[OCS] returning 1, *out=%p\\n", (void*)*out);
    return 1;
}'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('added more debug')
