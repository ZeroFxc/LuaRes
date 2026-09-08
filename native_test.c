/* native_test.c - Native test for const_hide with zeus script */
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int luaopen_luac(lua_State *L);

static char *read_file(const char *path, size_t *out_len) {
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "Cannot open %s\n", path); return NULL; }
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = malloc(len + 1);
    fread(buf, 1, len, f);
    buf[len] = '\0';
    fclose(f);
    *out_len = (size_t)len;
    return buf;
}

int main(int argc, char **argv) {
    const char *src_path = (argc > 1) ? argv[1] : "zeus_customer_source_debug.lua";
    const char *module = (argc > 2) ? argv[2] : "const_hide_c";
    const char *out_path = (argc > 3) ? argv[3] : "zeus_out.luac";

    fprintf(stderr, "=== Native Test ===\n");
    fprintf(stderr, "Source: %s\nModule: %s\nOutput: %s\n", src_path, module, out_path);

    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    luaL_requiref(L, "luac", luaopen_luac, 1);
    lua_pop(L, 1);

    /* Read source */
    size_t src_len;
    char *src = read_file(src_path, &src_len);
    if (!src) return 1;
    fprintf(stderr, "Source read: %zu bytes\n", src_len);

    /* Compile to bytecode */
    if (luaL_loadbuffer(L, src, src_len, "@zeus.lua") != LUA_OK) {
        fprintf(stderr, "Compile error: %s\n", lua_tostring(L, -1));
        return 1;
    }
    /* Dump bytecode: string.dump -> andlua shell, string.dec -> 0x1A raw bytecode */
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "dump");
    lua_remove(L, -2); /* remove string table, keep dump func */
    lua_pushvalue(L, -2); /* copy func */
    lua_pushboolean(L, 0); /* keep debug info */
    if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
        fprintf(stderr, "string.dump error: %s\n", lua_tostring(L, -1));
        return 1;
    }
    lua_remove(L, -2); /* remove func, keep shell string */
    /* stack: shell (=... base64) */
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "dec");
    lua_remove(L, -2);
    lua_pushvalue(L, -2); /* copy shell */
    if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
        fprintf(stderr, "string.dec error: %s\n", lua_tostring(L, -1));
        return 1;
    }
    lua_remove(L, -2); /* remove shell, keep raw bytecode */
    size_t bc_len;
    const char *bc = lua_tolstring(L, -1, &bc_len);
    fprintf(stderr, "Bytecode: %zu bytes, first 8 bytes:", bc_len);
    for (int i = 0; i < 8 && i < (int)bc_len; i++) fprintf(stderr, " %02X", (unsigned char)bc[i]);
    fprintf(stderr, "\n");

    /* undump to proto */
    lua_getglobal(L, "luac");
    lua_getfield(L, -1, "undump");
    lua_pushlstring(L, bc, bc_len);
    lua_pushboolean(L, 0);
    if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
        fprintf(stderr, "undump error: %s\n", lua_tostring(L, -1));
        return 1;
    }
    fprintf(stderr, "Proto loaded\n");

    /* Apply module */
    lua_getglobal(L, "luac");
    lua_getfield(L, -1, module);
    if (!lua_isfunction(L, -1)) {
        fprintf(stderr, "Module %s not found\n", module);
        return 1;
    }
    lua_pushvalue(L, -3); /* proto */
    fprintf(stderr, "Applying %s...\n", module);
    fflush(stderr);
    if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
        fprintf(stderr, "Module error: %s\n", lua_tostring(L, -1));
        return 1;
    }
    int count = (int)lua_tointeger(L, -1);
    fprintf(stderr, "Module %s OK, count=%d\n", module, count);

    /* Dump result */
    lua_getglobal(L, "luac");
    lua_getfield(L, -1, "dump");
    lua_pushvalue(L, -3); /* proto */
    if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
        fprintf(stderr, "dump error: %s\n", lua_tostring(L, -1));
        return 1;
    }
    size_t out_len;
    const char *out = lua_tolstring(L, -1, &out_len);
    FILE *f = fopen(out_path, "wb");
    fwrite(out, 1, out_len, f);
    fclose(f);
    fprintf(stderr, "Output saved: %zu bytes -> %s\n", out_len, out_path);
    fprintf(stderr, "=== DONE ===\n");

    free(src);
    lua_close(L);
    return 0;
}
