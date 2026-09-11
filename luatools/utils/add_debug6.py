path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add debug to obf_compile_subproto
content = content.replace(
    'luac_Proto *obf_compile_subproto(lua_State *L, const char *src) {\n    int top = lua_gettop(L);',
    'luac_Proto *obf_compile_subproto(lua_State *L, const char *src) {\n    int top = lua_gettop(L);\n    fprintf(stderr, "DBG: compile_subproto entry top=%d\\n", top); fflush(stderr);'
)

content = content.replace(
    '    if (luaL_loadstring(L, src) != LUA_OK) {',
    '    fprintf(stderr, "DBG: loading string\\n"); fflush(stderr);\n    if (luaL_loadstring(L, src) != LUA_OK) {'
)

content = content.replace(
    '    /* luac.undump(bc, false) -> main proto userdata */',
    '    fprintf(stderr, "DBG: calling luac.undump\\n"); fflush(stderr);\n    /* luac.undump(bc, false) -> main proto userdata */'
)

content = content.replace(
    '    luac_Proto *main_p = (luac_Proto *)luaL_checkudata(L, -1, "luac.Proto");',
    '    luac_Proto *main_p = (luac_Proto *)luaL_checkudata(L, -1, "luac.Proto");\n    fprintf(stderr, "DBG: main_p=%p sizep=%d\\n", (void*)main_p, main_p->sizep); fflush(stderr);'
)

content = content.replace(
    '    /* create userdata for sub-proto (takes ownership of arrays) */',
    '    fprintf(stderr, "DBG: pushing sub_proto\\n"); fflush(stderr);\n    /* create userdata for sub-proto (takes ownership of arrays) */'
)

content = content.replace(
    '    luac_Proto *sub_ud = (luac_Proto *)lua_touserdata(L, -1);',
    '    luac_Proto *sub_ud = (luac_Proto *)lua_touserdata(L, -1);\n    fprintf(stderr, "DBG: sub_ud=%p\\n", (void*)sub_ud); fflush(stderr);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
