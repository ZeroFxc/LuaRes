path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace obf_compile_subproto to return raw proto instead of userdata
old_start = content.find('luac_Proto *obf_compile_subproto(')
old_end = content.find('\n/*=====', old_start + 10)
old_func = content[old_start:old_end]

new_func = '''luac_Proto *obf_compile_subproto(lua_State *L, const char *src) {
    int top = lua_gettop(L);

    if (luaL_loadstring(L, src) != LUA_OK) {
        lua_settop(L, top);
        return NULL;
    }

    /* string.dump(func) */
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "dump");
    lua_pushvalue(L, -3);
    lua_call(L, 1, 1);

    /* string.dec if available */
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "dec");
    if (lua_isfunction(L, -1)) {
        lua_pushvalue(L, -3);
        lua_call(L, 1, 1);
        lua_replace(L, -3);
        lua_pop(L, 1);
    } else {
        lua_pop(L, 2);
    }

    /* luac.undump(bc, false) -> main proto userdata */
    lua_getglobal(L, "luac");
    lua_getfield(L, -1, "undump");
    lua_pushvalue(L, -3);
    lua_pushboolean(L, 0);
    lua_call(L, 2, 1);

    luac_Proto *main_p = (luac_Proto *)luaL_checkudata(L, -1, "luac.Proto");

    /* get first sub-proto (raw struct pointer) */
    luac_Proto *sub_raw = NULL;
    if (main_p->p && main_p->sizep >= 1) {
        sub_raw = main_p->p[0];
    }
    if (!sub_raw) {
        lua_settop(L, top);
        return NULL;
    }

    /* fix upvalue */
    if (sub_raw->upval_instack && sub_raw->sizeupvalues > 0) {
        sub_raw->upval_instack[0] = 0;
        sub_raw->upval_idx[0] = 0;
    }

    /* detach from main proto so main's GC doesn't free it */
    main_p->p[0] = NULL;
    main_p->sizep = 0;

    /* cleanup stack */
    lua_settop(L, top);

    return sub_raw;
}
'''

content = content[:old_start] + new_func + content[old_end:]

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
