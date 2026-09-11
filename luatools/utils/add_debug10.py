path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add debug at key points in obf_compile_subproto
content = content.replace(
    'int obf_compile_subproto(lua_State *L, const char *src, luac_Proto **out) {\n    int top = lua_gettop(L);',
    'int obf_compile_subproto(lua_State *L, const char *src, luac_Proto **out) {\n    int top = lua_gettop(L);\n    fprintf(stderr, "DBG cs: entry top=%d\\n", top); fflush(stderr);'
)

content = content.replace(
    '    if (luaL_loadstring(L, src) != LUA_OK) {',
    '    fprintf(stderr, "DBG cs: loadstring\\n"); fflush(stderr);\n    if (luaL_loadstring(L, src) != LUA_OK) {'
)

content = content.replace(
    '    /* luac.undump(bc, false) -> main proto userdata */',
    '    fprintf(stderr, "DBG cs: undump\\n"); fflush(stderr);\n    /* luac.undump(bc, false) -> main proto userdata */'
)

content = content.replace(
    '    luac_Proto *main_p = (luac_Proto *)luaL_checkudata(L, -1, "luac.Proto");',
    '    luac_Proto *main_p = (luac_Proto *)luaL_checkudata(L, -1, "luac.Proto");\n    fprintf(stderr, "DBG cs: main_p=%p sizep=%d\\n", (void*)main_p, main_p->sizep); fflush(stderr);'
)

content = content.replace(
    '    /* detach from main proto so main\'s GC doesn\'t free it */',
    '    fprintf(stderr, "DBG cs: detach\\n"); fflush(stderr);\n    /* detach from main proto so main\'s GC doesn\'t free it */'
)

content = content.replace(
    '    lua_settop(L, top);\n    *out = sub_raw;\n    return 1;',
    '    fprintf(stderr, "DBG cs: settop\\n"); fflush(stderr);\n    lua_settop(L, top);\n    fprintf(stderr, "DBG cs: sub_raw=%p maxstack=%d\\n", (void*)sub_raw, sub_raw->maxstacksize); fflush(stderr);\n    *out = sub_raw;\n    return 1;'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
