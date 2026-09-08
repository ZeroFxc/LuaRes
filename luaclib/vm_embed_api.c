/*
** vm_embed_api.c - Lua API for vm_embed (self-contained VM generator)
**
** luac.vm_embed_c(proto) -> lua source string
** Dumps proto to bytecode, then calls vm_embed_generate to produce
** a self-contained Lua source file that runs without string.dec/luac.
*/
#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <string.h>
#include "obf_util.h"
#include "luac.h"
#include "vm_asm.h"

char *vm_embed_generate(const unsigned char *bc, size_t bc_len, int luajit_compat, size_t *out_len);

int vm_embed_process(lua_State *L) {
    { FILE *df = fopen("_vm_dbg.txt", "w"); fprintf(df, "vm_embed_process called\n"); fclose(df); }
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    /* optional options table */
    int luajit_compat = 0;
    if (lua_istable(L, 2)) {
        lua_getfield(L, 2, "luajit_compat");
        if (lua_toboolean(L, -1)) luajit_compat = 1;
        lua_pop(L, 1);
    }

    /* dump proto to bytecode */
    lua_getglobal(L, "luac");
    lua_getfield(L, -1, "dump");
    lua_remove(L, -2);
    lua_pushvalue(L, 1); /* proto */
    if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
        const char *err = lua_tostring(L, -1);
        return luaL_error(L, "vm_embed dump: %s", err ? err : "?");
    }
    size_t bc_len = 0;
    const char *bc_str = lua_tolstring(L, -1, &bc_len);
    if (!bc_str || bc_len == 0) {
        return luaL_error(L, "vm_embed: empty dump");
    }
    unsigned char *bc = (unsigned char *)malloc(bc_len);
    memcpy(bc, bc_str, bc_len);
    lua_pop(L, 1);

    /* generate self-contained VM source */
    size_t src_len = 0;
    char *src = vm_embed_generate(bc, bc_len, luajit_compat, &src_len);
    free(bc);
    if (!src) {
        return luaL_error(L, "vm_embed: generation failed");
    }

    lua_pushlstring(L, src, src_len);
    free(src);
    return 1;
}
