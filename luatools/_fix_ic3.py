p = r'E:\LuaRes\luaclib\integrity_check.c'
s = open(p, encoding='utf-8').read()

old = """    lua_State *L = luaL_newstate();
    if (!L) return NULL;
    luaL_openlibs(L);
    luaopen_luac(L); /* 加载 luac 库 */"""

new = """    lua_State *L = luaL_newstate();
    if (!L) return NULL;
    /* 手动打开需要的标准库（WASM 中 luaL_openlibs 可能不可用） */
    lua_pushcfunction(L, luaopen_base); lua_pushstring(L, ""); lua_call(L, 1, 0);
    lua_pushcfunction(L, luaopen_string); lua_pushstring(L, LUA_STRLIBNAME); lua_call(L, 1, 0);
    lua_pushcfunction(L, luaopen_debug); lua_pushstring(L, LUA_DBLIBNAME); lua_call(L, 1, 0);
    lua_pushcfunction(L, luaopen_table); lua_pushstring(L, LUA_TABLIBNAME); lua_call(L, 1, 0);
    luaopen_luac(L); /* 加载 luac 库 */"""

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('done')
