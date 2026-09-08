p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

old = '''static int run_print(lua_State *L) {
    int n = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, g_run_output_ref);
    int len = (int)lua_rawlen(L, -1);
    for (int i = 1; i <= n; i++) {
        lua_getglobal(L, "tostring");
        lua_pushvalue(L, i);
        lua_call(L, 1, 1);
        const char *s = lua_tostring(L, -1);
        if (s) {
            lua_pushstring(L, s);
            lua_rawseti(L, -3, ++len);
        }
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
    return 0;
}

static int run_write(lua_State *L) {
    /* capture io.write output too */
    int n = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, g_run_output_ref);
    int len = (int)lua_rawlen(L, -1);
    for (int i = 1; i <= n; i++) {
        if (lua_isstring(L, i)) {
            const char *s = lua_tostring(L, i);
            lua_pushstring(L, s);
            lua_rawseti(L, -2, ++len);
        }
    }
    lua_pop(L, 1);
    return 0;
}'''

new = '''static int run_print(lua_State *L) {
    int n = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, g_run_output_ref);
    int len = (int)lua_rawlen(L, -1);
    for (int i = 1; i <= n; i++) {
        lua_getglobal(L, "tostring");
        lua_pushvalue(L, i);
        lua_call(L, 1, 1);
        size_t slen;
        const char *s = lua_tolstring(L, -1, &slen);
        if (s) {
            lua_pushlstring(L, s, slen);
            lua_rawseti(L, -3, ++len);
        }
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
    return 0;
}

static int run_write(lua_State *L) {
    /* capture io.write output too */
    int n = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, g_run_output_ref);
    int len = (int)lua_rawlen(L, -1);
    for (int i = 1; i <= n; i++) {
        if (lua_isstring(L, i)) {
            size_t slen;
            const char *s = lua_tolstring(L, i, &slen);
            lua_pushlstring(L, s, slen);
            lua_rawseti(L, -2, ++len);
        }
    }
    lua_pop(L, 1);
    return 0;
}'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
