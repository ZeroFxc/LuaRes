with open(r'E:\LuaRes\luaclib\luac.c', 'r', encoding='utf-8') as f:
    content = f.read()

old = """    luac_Proto *f = luac_alloc(sizeof(luac_Proto));
    LoadFunction(&S, f);

    push_proto(L, f);"""

new = """    luac_Proto *f = luac_alloc(sizeof(luac_Proto));
    LoadFunction(&S, f);

#if LUACLIB_DEBUG
    fprintf(stderr, "[luac] undump done: parsed=%zu total=%zu tail=%zu\\n", S.pos, S.len, S.len - S.pos);
#endif

    push_proto(L, f);"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luaclib\luac.c', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
