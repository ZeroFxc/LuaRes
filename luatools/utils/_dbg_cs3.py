path = r'E:\LuaRes\luaclib\const_shuffle.c'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

old = '''int const_shuffle_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    obf_srand((unsigned int)time(NULL));
    shuffle_function(p);
    lua_pushinteger(L, 1);
    return 1;
}'''

new = '''int const_shuffle_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    fprintf(stderr, "[cs] got proto sizek=%d sizecode=%d sizep=%d\\n", p->sizek, p->sizecode, p->sizep);
    fprintf(stderr, "[cs] k_tag=%p k_str=%p code=%p p=%p\\n", (void*)p->k_tag, (void*)p->k_str, (void*)p->code, (void*)p->p);
    obf_invalidate_all_caches(L, p);
    fprintf(stderr, "[cs] invalidate done\\n");
    obf_srand((unsigned int)time(NULL));
    shuffle_function(p);
    fprintf(stderr, "[cs] shuffle done\\n");
    lua_pushinteger(L, 1);
    return 1;
}'''

src = src.replace(old, new)
with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
print("debug added")
