/* test_entry.c - 测试入口：注册 luac 模块后运行脚本 */
#include <stdio.h>
#include <stdlib.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

int luaopen_luac(lua_State *L);

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <script.lua> [args...]\n", argv[0]);
        return 1;
    }
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    luaopen_luac(L);
    lua_setglobal(L, "luac");

    /* 把剩余参数作为 arg 传给脚本 */
    lua_newtable(L);
    for (int i = 2; i < argc; i++) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i - 1);
    }
    lua_setglobal(L, "arg");

    if (luaL_dofile(L, argv[1]) != LUA_OK) {
        const char *err = lua_tostring(L, -1);
        fprintf(stderr, "%s\n", err ? err : "?");
        lua_close(L);
        return 1;
    }
    lua_close(L);
    return 0;
}
