/*
** wasm_entry.c - Emscripten WASM interface for luac obfuscation
**
** === Built-in Module API ===
**   wasm_init()              - initialize Lua state + luac module
**   wasm_load(ptr,len)       - load bytecode, return handle (registry ref)
**   wasm_apply(h,name)       - apply built-in module by name
**   wasm_dump(h,*outlen)     - dump bytecode to malloc'd buffer, return ptr
**   wasm_free_dump(ptr)      - free dump buffer
**   wasm_free(h)             - release proto handle
**   wasm_modules()           - comma-separated built-in module names
**   wasm_last_error()        - last error message
**   wasm_shutdown()          - close Lua state
**
** === Custom Module API ===
**   Custom Lua modules are registered via wasm_register_module().
**   A module is a Lua chunk that returns a table:
**
**     return {
**         name        = "my_mod",    -- required, unique identifier
**         label       = "我的模块",   -- optional, display name
**         description = "描述",       -- optional
**         apply       = function(proto)
**             -- proto is a luac.Proto userdata
**             -- modify proto.code, proto.k, proto.p, etc.
**             -- built-in luac.* functions are available
**             return true  -- success
**         end
**     }
**
**   wasm_register_module(ptr,len)  - register custom Lua module source
**   wasm_apply_custom(h,name)      - apply custom module by name
**   wasm_custom_modules()           - comma-separated custom module names
**   wasm_all_modules()              - built-in + custom module names
**   wasm_module_info(name)          - JSON-ish info for a module
**
** === Bytecode Runtime API ===
**   wasm_run_bytecode(ptr,len,*outlen) - run bytecode, capture stdout, return malloc'd string
**   wasm_free_output(ptr)               - free run output
*/
#include <emscripten.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <time.h>
#include "luac.h"
#include "obf_util.h"
#include "vm_asm/vm_asm.h"

static lua_State *g_L = NULL;
static char g_errbuf[2048];
/* run timeout: 5s default, checked via instruction-count hook */
static int g_run_timeout_ms = 5000;
static double g_run_start_ms = 0;
static int g_run_timed_out = 0;

/* Registry key for custom modules table */
#define CUSTOM_MODS_KEY "luac_custom_modules"

/* Built-in module list in forward application order */
static const char *MODULE_LIST =
    "bool_obfuscate_c,"
    "num_obfuscate_c,"
    "str_split_c,"
    "const_hide_c,"
    "str_encrypt_c,"
    "const_shuffle_c,"
    "instruction_mutate_c,"
    "table_obfuscate_c,"
    "opaque_predicate_c,"
    "const_poison_c,"
    "opaque_junk_c,"
    "junk_jmp_c,"
    "junk_loadk_c,"
    "junk_move_c,"
    "op48_junk_c,"
    "luac_obfuscate_c,"
    "luac_flatten_c,"
    "debug_strip_c,"
    "antidec_c,"
    "condition_split_c,"
    "loop_restructure_c,"
    "for_loop_unroll_c,"
    "tforcall_to_call_c,"
    "tforloop_as_jump_c,"
    "fake_forloop_c,"
    "operator_substitute_c,"
    "debug_mutate_c,"
    "call_rewrite_c,"
    "upvalue_promote_c,"
    "block_clone_c,"
    "cfg_shuffle_c,"
    "vm_dispatch_shuffle_c,"
    "vm_reg_shuffle_c,"
    "vm_const_shuffle_c,"
    "nested_flatten_c,"
    "indirect_dispatch_c,"
    "exception_flow_c,"
    "exception_dispatcher_c,"
    "jmp_split_c,"
    "upvalue_channel_c,"
    "tailcall_chain_c,"
    "parallel_state_c,"
    "unary_chain_c,"
    "self_expand_c,"
    "fake_function_c";

/*===========================================================================
** Helpers
**=========================================================================*/

static void set_error(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(g_errbuf, sizeof(g_errbuf), fmt, ap);
    va_end(ap);
}

static void get_custom_table(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, CUSTOM_MODS_KEY);
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        lua_newtable(L);
        lua_pushvalue(L, -1);
        lua_setfield(L, LUA_REGISTRYINDEX, CUSTOM_MODS_KEY);
    }
}

/*===========================================================================
** Built-in API
**=========================================================================*/

EMSCRIPTEN_KEEPALIVE
int wasm_init(void) {
    fprintf(stderr, "[WASM_ENTRY] wasm_init called\n");
    /* randomize per init so obfuscation output is non-deterministic
       (native path seeds via luac.srand; wasm had a fixed xorshift
       state and always produced the same pattern sequence) */
    obf_srand_force((unsigned int)time(NULL));
    if (g_L) return 0;
    g_L = luaL_newstate();
    if (!g_L) return -1;
    luaL_openlibs(g_L);
    lua_getglobal(g_L, "require");
    lua_pushstring(g_L, "luac");
    if (lua_pcall(g_L, 1, 1, 0) != LUA_OK) {
        const char *err = lua_tostring(g_L, -1);
        set_error("require luac failed: %s", err ? err : "?");
        lua_pop(g_L, 1);
        lua_close(g_L);
        g_L = NULL;
        return -1;
    }
    lua_pop(g_L, 1);
    /* create custom modules registry table */
    lua_newtable(g_L);
    lua_setfield(g_L, LUA_REGISTRYINDEX, CUSTOM_MODS_KEY);
    vm_dispatch_reset();  /* clear any previous explicit dispatch opts */
    vm_reg_shuffle_reset();
    vm_const_shuffle_reset();
    g_errbuf[0] = '\0';
    return 0;
}

EMSCRIPTEN_KEEPALIVE
void wasm_dispatch_opts(int mode, int seed) {
    vm_dispatch_set_explicit((unsigned int)seed, mode);
}

EMSCRIPTEN_KEEPALIVE
void wasm_vm_shuffle_opts(int reg_seed, int const_seed) {
    if (reg_seed >= 0) vm_reg_shuffle_set((unsigned int)reg_seed);
    else vm_reg_shuffle_reset();
    if (const_seed >= 0) vm_const_shuffle_set((unsigned int)const_seed);
    else vm_const_shuffle_reset();
}

EMSCRIPTEN_KEEPALIVE
/* dump writer for normalizing input to raw bytecode */
typedef struct { unsigned char *data; size_t len; size_t cap; } norm_buf;
static int norm_writer(lua_State *L, const void *p, size_t sz, void *ud) {
    norm_buf *buf = (norm_buf *)ud;
    (void)L;
    if (buf->len + sz > buf->cap) {
        buf->cap = (buf->len + sz) * 2;
        buf->data = realloc(buf->data, buf->cap);
    }
    memcpy(buf->data + buf->len, p, sz);
    buf->len += sz;
    return 0;
}

/* Standard bytecode writer (0x1B, plaintext strings). Used instead of the
   andlua shell path: the shell encrypts every string, and the heuristic
   decryptor (is_valid_text) corrupts legitimate binary/control-char strings. */
static int wasm_dump_writer (lua_State *L, const void *b, size_t size, void *ud) {
    (void)L;
    luaL_Buffer *buf = (luaL_Buffer *)ud;
    luaL_addlstring(buf, (const char *)b, size);
    return 0;
}

/* Normalize any input (raw bytecode / plain source / =andlua shell / 0x1C) to 0x1A bytecode.
   Returns malloc'd buffer or NULL on error. *out_len set to size. */
static unsigned char *normalize_to_bytecode(const unsigned char *data, int len, size_t *out_len) {
    *out_len = 0;
    unsigned char first = data[0];
    /* Raw bytecode: use directly */
    if (first == 0x1B || first == 0x1A) {
        unsigned char *copy = malloc(len);
        memcpy(copy, data, len);
        *out_len = len;
        return copy;
    }
    /* Everything else: load (compiles source), then dump standard 0x1B
       bytecode directly. Do NOT go through string.dump/string.dec (andlua
       shell): that round-trip encrypts all strings and the heuristic decrypt
       keeps binary/control-char strings in their encrypted (corrupted) form. */
    if (luaL_loadbufferx(g_L, (const char *)data, (size_t)len, "=input", NULL) != LUA_OK) {
        const char *err = lua_tostring(g_L, -1);
        set_error("load: %s", err ? err : "?");
        lua_pop(g_L, 1);
        return NULL;
    }
    /* stack: func */
    luaL_Buffer b;
    luaL_buffinit(g_L, &b);
    if (lua_dump(g_L, wasm_dump_writer, &b, 0) != 0) {
        const char *err = lua_tostring(g_L, -1);
        set_error("string.dump: %s", err ? err : "?");
        lua_pop(g_L, 1);
        return NULL;
    }
    luaL_pushresult(&b);
    /* stack: 0x1B bytecode string */
    size_t raw_len = 0;
    const char *raw_str = lua_tolstring(g_L, -1, &raw_len);
    unsigned char *raw = malloc(raw_len);
    memcpy(raw, raw_str, raw_len);
    lua_pop(g_L, 1);
    *out_len = raw_len;
    return raw;
}

int wasm_load(const unsigned char *data, int len) {
    if (!g_L || !data || len <= 0) {
        set_error("wasm_load: invalid state or data");
        return LUA_NOREF;
    }
    size_t raw_len = 0;
    vm_dispatch_reset();
    vm_reg_shuffle_reset();
    vm_const_shuffle_reset();
    unsigned char *raw = normalize_to_bytecode(data, len, &raw_len);
    if (!raw) return LUA_NOREF;
    lua_getglobal(g_L, "luac");
    if (!lua_istable(g_L, -1)) {
        lua_pop(g_L, 1);
        free(raw);
        set_error("wasm_load: luac table not found");
        return LUA_NOREF;
    }
    lua_getfield(g_L, -1, "undump");
    lua_remove(g_L, -2);
    lua_pushlstring(g_L, (const char *)raw, raw_len);
    lua_pushboolean(g_L, 1); /* force_encrypted: plain-source path dumps via
                                luasafe lua_dump which encrypts every string */
    (void)0;
    free(raw);
    if (lua_pcall(g_L, 2, 1, 0) != LUA_OK) {
        const char *err = lua_tostring(g_L, -1);
        set_error("undump: %s", err ? err : "?");
        lua_pop(g_L, 1);
        return LUA_NOREF;
    }
    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    g_errbuf[0] = '\0';
    lua_gc(g_L, LUA_GCCOLLECT, 0);
    return ref;
}

EMSCRIPTEN_KEEPALIVE
int wasm_apply(int handle, const char *module_name) {
    if (!g_L || !module_name) { set_error("wasm_apply: invalid args"); return -1; }
    if (handle < 0) { set_error("wasm_apply: invalid handle"); return -1; }
    lua_getglobal(g_L, "luac");
    lua_getfield(g_L, -1, module_name);
    if (!lua_isfunction(g_L, -1)) {
        set_error("module not found: %s", module_name);
        lua_pop(g_L, 2);
        return -1;
    }
    lua_remove(g_L, -2);
    lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
    if (lua_pcall(g_L, 1, 1, 0) != LUA_OK) {
        const char *err = lua_tostring(g_L, -1);
        set_error("%s: %s", module_name, err ? err : "?");
        lua_pop(g_L, 1);
        return -1;
    }
    lua_pop(g_L, 1);
    g_errbuf[0] = '\0';
    return 0;
}

EMSCRIPTEN_KEEPALIVE
unsigned char *wasm_dump(int handle, int *out_len) {
    if (!g_L || !out_len || handle < 0) {
        set_error("wasm_dump: invalid args");
        *out_len = 0;
        return NULL;
    }
    *out_len = 0;
    lua_getglobal(g_L, "luac");
    lua_getfield(g_L, -1, "dump");
    lua_remove(g_L, -2);
    lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
    if (lua_pcall(g_L, 1, 1, 0) != LUA_OK) {
        const char *err = lua_tostring(g_L, -1);
        set_error("dump: %s", err ? err : "?");
        lua_pop(g_L, 1);
        return NULL;
    }
    size_t len = 0;
    const char *s = lua_tolstring(g_L, -1, &len);
    if (!s || len == 0) {
        set_error("dump: empty result");
        lua_pop(g_L, 1);
        return NULL;
    }
    unsigned char *buf = (unsigned char *)malloc(len);
    if (!buf) { set_error("dump: malloc failed"); lua_pop(g_L, 1); return NULL; }
    memcpy(buf, s, len);
    lua_pop(g_L, 1);
    *out_len = (int)len;
    g_errbuf[0] = '\0';
    return buf;
}

EMSCRIPTEN_KEEPALIVE
void wasm_free_dump(unsigned char *ptr) { if (ptr) free(ptr); }

/* vm_embed: convert proto to self-contained Lua source (成品式 VM) */
EMSCRIPTEN_KEEPALIVE
char *wasm_vm_embed(int handle, int luajit_compat, int *out_len) {
    if (!g_L || !out_len || handle < 0) {
        set_error("wasm_vm_embed: invalid args");
        *out_len = 0;
        return NULL;
    }
    *out_len = 0;
    lua_getglobal(g_L, "luac");
    lua_getfield(g_L, -1, "dump");
    lua_remove(g_L, -2);
    lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
    if (lua_pcall(g_L, 1, 1, 0) != LUA_OK) {
        const char *err = lua_tostring(g_L, -1);
        set_error("vm_embed dump: %s", err ? err : "?");
        lua_pop(g_L, 1);
        return NULL;
    }
    size_t bc_len = 0;
    const char *bc_str = lua_tolstring(g_L, -1, &bc_len);
    if (!bc_str || bc_len == 0) {
        set_error("vm_embed: empty dump");
        lua_pop(g_L, 1);
        return NULL;
    }
    unsigned char *bc = (unsigned char *)malloc(bc_len);
    memcpy(bc, bc_str, bc_len);
    lua_pop(g_L, 1);

    size_t src_len = 0;
    char *src = vm_embed_generate(bc, bc_len, luajit_compat, &src_len);
    free(bc);
    if (!src) {
        set_error("vm_embed: generation failed");
        return NULL;
    }
    *out_len = (int)src_len;
    g_errbuf[0] = '\0';
    lua_gc(g_L, LUA_GCCOLLECT, 0);
    return src;
}

EMSCRIPTEN_KEEPALIVE
void wasm_free(int handle) {
    if (!g_L || handle < 0) return;
    luaL_unref(g_L, LUA_REGISTRYINDEX, handle);
}

EMSCRIPTEN_KEEPALIVE
const char *wasm_modules(void) { return MODULE_LIST; }

EMSCRIPTEN_KEEPALIVE
const char *wasm_last_error(void) { return g_errbuf; }

EMSCRIPTEN_KEEPALIVE
void wasm_shutdown(void) {
    if (g_L) { lua_close(g_L); g_L = NULL; }
}

/*===========================================================================
** Custom Module API
**=========================================================================*/

EMSCRIPTEN_KEEPALIVE
int wasm_register_module(const char *code, int code_len) {
    if (!g_L || !code || code_len <= 0) {
        set_error("wasm_register_module: invalid args");
        return -1;
    }
    /* load module chunk */
    if (luaL_loadbuffer(g_L, code, (size_t)code_len, "custom_module") != LUA_OK) {
        const char *err = lua_tostring(g_L, -1);
        set_error("module load error: %s", err ? err : "?");
        lua_pop(g_L, 1);
        return -1;
    }
    /* execute to get module table */
    if (lua_pcall(g_L, 0, 1, 0) != LUA_OK) {
        const char *err = lua_tostring(g_L, -1);
        set_error("module exec error: %s", err ? err : "?");
        lua_pop(g_L, 1);
        return -1;
    }
    if (!lua_istable(g_L, -1)) {
        set_error("module must return a table");
        lua_pop(g_L, 1);
        return -1;
    }
    /* validate required fields */
    lua_getfield(g_L, -1, "name");
    if (!lua_isstring(g_L, -1)) {
        set_error("module table missing 'name' field");
        lua_pop(g_L, 2);
        return -1;
    }
    const char *name = lua_tostring(g_L, -1);
    lua_pop(g_L, 1);

    lua_getfield(g_L, -1, "apply");
    if (!lua_isfunction(g_L, -1)) {
        set_error("module '%s' missing 'apply' function", name);
        lua_pop(g_L, 2);
        return -1;
    }
    lua_pop(g_L, 1);

    /* store in custom modules registry table */
    get_custom_table(g_L);
    lua_pushvalue(g_L, -2); /* module table */
    lua_setfield(g_L, -2, name);
    lua_pop(g_L, 2); /* custom table + module table */

    g_errbuf[0] = '\0';
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int wasm_apply_custom(int handle, const char *name) {
    if (!g_L || !name) { set_error("wasm_apply_custom: invalid args"); return -1; }
    if (handle < 0) { set_error("wasm_apply_custom: invalid handle"); return -1; }

    get_custom_table(g_L);
    lua_getfield(g_L, -1, name);
    if (!lua_istable(g_L, -1)) {
        set_error("custom module not found: %s", name);
        lua_pop(g_L, 2);
        return -1;
    }
    lua_getfield(g_L, -1, "apply");
    if (!lua_isfunction(g_L, -1)) {
        set_error("custom module '%s' has no apply function", name);
        lua_pop(g_L, 3);
        return -1;
    }
    lua_remove(g_L, -2); /* remove module table, keep apply func */
    lua_remove(g_L, -2); /* remove custom table */

    lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
    if (lua_pcall(g_L, 1, 1, 0) != LUA_OK) {
        const char *err = lua_tostring(g_L, -1);
        set_error("%s: %s", name, err ? err : "?");
        lua_pop(g_L, 1);
        return -1;
    }
    lua_pop(g_L, 1);
    g_errbuf[0] = '\0';
    return 0;
}

EMSCRIPTEN_KEEPALIVE
const char *wasm_custom_modules(void) {
    static char buf[8192];
    buf[0] = '\0';
    if (!g_L) return buf;
    get_custom_table(g_L);
    int pos = 0;
    int first = 1;
    lua_pushnil(g_L);
    while (lua_next(g_L, -2) != 0) {
        if (lua_isstring(g_L, -2)) {
            const char *name = lua_tostring(g_L, -2);
            int nlen = (int)strlen(name);
            if (!first) {
                if (pos + 1 < (int)sizeof(buf)) buf[pos++] = ',';
            }
            if (pos + nlen < (int)sizeof(buf)) {
                memcpy(buf + pos, name, nlen);
                pos += nlen;
            }
            first = 0;
        }
        lua_pop(g_L, 1);
    }
    lua_pop(g_L, 1); /* custom table */
    buf[pos] = '\0';
    return buf;
}

EMSCRIPTEN_KEEPALIVE
const char *wasm_all_modules(void) {
    static char buf[16384];
    const char *custom = wasm_custom_modules();
    if (custom && custom[0]) {
        snprintf(buf, sizeof(buf), "%s,%s", MODULE_LIST, custom);
    } else {
        snprintf(buf, sizeof(buf), "%s", MODULE_LIST);
    }
    return buf;
}

/* Return module info as a simple string: "name|label|description" */
EMSCRIPTEN_KEEPALIVE
const char *wasm_module_info(const char *name) {
    static char buf[1024];
    buf[0] = '\0';
    if (!g_L || !name) return buf;

    /* check custom modules first */
    get_custom_table(g_L);
    lua_getfield(g_L, -1, name);
    if (lua_istable(g_L, -1)) {
        const char *label = name;
        const char *desc = "";
        lua_getfield(g_L, -1, "label");
        if (lua_isstring(g_L, -1)) label = lua_tostring(g_L, -1);
        lua_pop(g_L, 1);
        lua_getfield(g_L, -1, "description");
        if (lua_isstring(g_L, -1)) desc = lua_tostring(g_L, -1);
        lua_pop(g_L, 1);
        snprintf(buf, sizeof(buf), "%s|%s|%s|custom", name, label, desc);
        lua_pop(g_L, 2);
        return buf;
    }
    lua_pop(g_L, 2);

    /* built-in module - check if it exists in luac table */
    lua_getglobal(g_L, "luac");
    if (lua_istable(g_L, -1)) {
        lua_getfield(g_L, -1, name);
        if (lua_isfunction(g_L, -1)) {
            snprintf(buf, sizeof(buf), "%s|%s|%s|builtin", name, name, "");
            lua_pop(g_L, 2);
            return buf;
        }
        lua_pop(g_L, 1);
    }
    lua_pop(g_L, 1);
    return buf;
}

/*===========================================================================
** Bytecode Runtime API (run in-page, capture output)
**=========================================================================*/

static int g_run_output_ref = LUA_NOREF;

static void timeout_hook(lua_State *L, lua_Debug *ar) {
    (void)ar;
    /* Full GC each hook tick. In wasm32 the incremental marker can visit a
       half-built proto graph while a large obfuscated chunk is loading or
       running (memory access out of bounds); full collection only ever sees a
       consistent object graph. */
    lua_gc(L, LUA_GCCOLLECT, 0);
    double now = emscripten_get_now();
    if (now - g_run_start_ms > (double)g_run_timeout_ms) {
        g_run_timed_out = 1;
        lua_sethook(L, NULL, 0, 0);
        luaL_error(L, "execution timeout (%d ms)", g_run_timeout_ms);
    }
}

static int run_print(lua_State *L) {
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
}

EMSCRIPTEN_KEEPALIVE
char *wasm_run_bytecode(const unsigned char *bc, int bc_len, int *out_len) {
    if (!g_L || !bc || bc_len <= 0 || !out_len) {
        set_error("wasm_run_bytecode: invalid args");
        *out_len = 0;
        return NULL;
    }
    *out_len = 0;

    /* Root fix: run the obfuscated chunk in a FRESH thread with its own stack.
       Generation reuses g_L and leaves GC objects (proto userdata / tables) in
       high stack slots; luaD_precall does not clear a new call frame, so when
       the rewritten chunk is run on g_L itself, its high registers can read
       those leftovers ("attempt to compare / do arithmetic on a table", and it
       keeps failing on every run until the page is reloaded = state rebuilt).
       A new thread owns a freshly allocated, zero-initialized stack while still
       sharing globals and the registry (all standard + andlua extensions stay
       available), removing the residue at its source rather than patching the
       bytecode. */
    lua_State *R = lua_newthread(g_L);
    int run_thread_ref = luaL_ref(g_L, LUA_REGISTRYINDEX); /* keep thread alive */

    /* Stop the incremental GC for the whole load+run. Lua 5.3's incremental
       marker interleaves with lundump allocations; on wasm32 with a large
       proto graph it can mark a half-constructed object and trap with
       "memory access out of bounds". We collect explicitly (full GC) after
       load and from the timeout hook, and restart the incremental collector on
       every exit path. */
    lua_gc(g_L, LUA_GCSTOP, 0);

    /* create output capture table */
    lua_newtable(g_L);
    g_run_output_ref = luaL_ref(g_L, LUA_REGISTRYINDEX);

    /* save original print and io.write */
    lua_getglobal(g_L, "print");
    int old_print = luaL_ref(g_L, LUA_REGISTRYINDEX);
    lua_getglobal(g_L, "io");
    if (lua_istable(g_L, -1)) {
        lua_getfield(g_L, -1, "write");
        int old_write = luaL_ref(g_L, LUA_REGISTRYINDEX);
        lua_pop(g_L, 1); /* io table */

        /* override print and io.write */
        lua_pushcfunction(g_L, run_print);
        lua_setglobal(g_L, "print");
        lua_getglobal(g_L, "io");
        lua_pushcfunction(g_L, run_write);
        lua_setfield(g_L, -2, "write");
        lua_pop(g_L, 1);

        /* load bytecode into the fresh thread R (independent stack) */
        int load_ok = (luaL_loadbuffer(R, (const char *)bc, (size_t)bc_len, "=obf_output") == LUA_OK);
        if (!load_ok) {
            const char *err = lua_tostring(R, -1);
            set_error("load error: %s", err ? err : "?");
            lua_pop(R, 1);
            /* restore */
            lua_rawgeti(g_L, LUA_REGISTRYINDEX, old_print);
            lua_setglobal(g_L, "print");
            lua_getglobal(g_L, "io");
            lua_rawgeti(g_L, LUA_REGISTRYINDEX, old_write);
            lua_setfield(g_L, -2, "write");
            lua_pop(g_L, 1);
            luaL_unref(g_L, LUA_REGISTRYINDEX, old_print);
            luaL_unref(g_L, LUA_REGISTRYINDEX, old_write);
            luaL_unref(g_L, LUA_REGISTRYINDEX, g_run_output_ref);
            g_run_output_ref = LUA_NOREF;
            luaL_unref(g_L, LUA_REGISTRYINDEX, run_thread_ref);
            lua_gc(g_L, LUA_GCRESTART, 0);
            return NULL;
        }

        /* Full collection after load: consistent object graph before execution. */
        lua_gc(R, LUA_GCCOLLECT, 0);

        /* pcall with timeout hook (on the fresh thread R) */
        g_run_start_ms = emscripten_get_now();
        g_run_timed_out = 0;
        lua_sethook(R, timeout_hook, LUA_MASKCOUNT, 100000);
        int pcall_ok = (lua_pcall(R, 0, 0, 0) == LUA_OK);
        lua_sethook(R, NULL, 0, 0);
        if (!pcall_ok) {
            const char *err = lua_tostring(R, -1);
            lua_pop(R, 1);
            /* append error to output (shared registry table) via g_L */
            lua_rawgeti(g_L, LUA_REGISTRYINDEX, g_run_output_ref);
            int len = (int)lua_rawlen(g_L, -1);
            lua_pushstring(g_L, err ? err : "runtime error");
            lua_rawseti(g_L, -2, ++len);
            lua_pop(g_L, 1); /* output table */
        }

        /* restore print and io.write */
        lua_rawgeti(g_L, LUA_REGISTRYINDEX, old_print);
        lua_setglobal(g_L, "print");
        lua_getglobal(g_L, "io");
        lua_rawgeti(g_L, LUA_REGISTRYINDEX, old_write);
        lua_setfield(g_L, -2, "write");
        lua_pop(g_L, 1);
        luaL_unref(g_L, LUA_REGISTRYINDEX, old_print);
        luaL_unref(g_L, LUA_REGISTRYINDEX, old_write);
    } else {
        lua_pop(g_L, 1);
        lua_pushcfunction(g_L, run_print);
        lua_setglobal(g_L, "print");
        if (luaL_loadbuffer(R, (const char *)bc, (size_t)bc_len, "=obf_output") == LUA_OK) {
            lua_gc(R, LUA_GCCOLLECT, 0); /* full collection after load */
            g_run_start_ms = emscripten_get_now();
            g_run_timed_out = 0;
            lua_sethook(R, timeout_hook, LUA_MASKCOUNT, 100000);
            lua_pcall(R, 0, 0, 0);
            lua_sethook(R, NULL, 0, 0);
        }
        lua_rawgeti(g_L, LUA_REGISTRYINDEX, old_print);
        lua_setglobal(g_L, "print");
        luaL_unref(g_L, LUA_REGISTRYINDEX, old_print);
    }

    /* collect output */
    lua_rawgeti(g_L, LUA_REGISTRYINDEX, g_run_output_ref);
    int n = (int)lua_rawlen(g_L, -1);
    size_t total = 0;
    for (int i = 1; i <= n; i++) {
        lua_rawgeti(g_L, -1, i);
        size_t slen;
        lua_tolstring(g_L, -1, &slen);
        total += slen + 1;
        lua_pop(g_L, 1);
    }
    char *out = (char *)malloc(total + 1);
    if (!out) {
        lua_pop(g_L, 1);
        luaL_unref(g_L, LUA_REGISTRYINDEX, g_run_output_ref);
        g_run_output_ref = LUA_NOREF;
        luaL_unref(g_L, LUA_REGISTRYINDEX, run_thread_ref);
        lua_gc(g_L, LUA_GCRESTART, 0);
        set_error("run: malloc failed");
        return NULL;
    }
    size_t pos = 0;
    for (int i = 1; i <= n; i++) {
        lua_rawgeti(g_L, -1, i);
        size_t slen;
        const char *s = lua_tolstring(g_L, -1, &slen);
        if (s && slen > 0) {
            memcpy(out + pos, s, slen);
            pos += slen;
        }
        out[pos++] = '\n';
        lua_pop(g_L, 1);
    }
    out[pos] = '\0';
    *out_len = (int)pos;
    lua_pop(g_L, 1); /* output table */
    luaL_unref(g_L, LUA_REGISTRYINDEX, g_run_output_ref);
    g_run_output_ref = LUA_NOREF;
    luaL_unref(g_L, LUA_REGISTRYINDEX, run_thread_ref);

    g_errbuf[0] = '\0';
    lua_gc(g_L, LUA_GCRESTART, 0);
    return out;
}

EMSCRIPTEN_KEEPALIVE
void wasm_free_output(char *ptr) { if (ptr) free(ptr); }

/*===========================================================================
** Bytecode Inspector API
**=========================================================================*/

/* Lua 5.3 opcode names (0-47) */
static const char *const INSPECT_OPNAMES[] = {
    "MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL",
    "GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL",
    "SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD",
    "POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR",
    "UNM","BNOT","NOT","LEN","CONCAT",
    "JMP","EQ","LT","LE",
    "TEST","TESTSET","CALL","TAILCALL","RETURN",
    "FORLOOP","FORPREP","TFORCALL","TFORLOOP",
    "SETLIST","CLOSURE","VARARG",
    "EXTRAARG", NULL
};

/* Dynamic string buffer */
typedef struct { char *buf; size_t len, cap; } SBuf;
static void sb_init(SBuf *sb){ sb->cap=8192; sb->buf=malloc(sb->cap); sb->len=0; sb->buf[0]=0; }
static void sb_grow(SBuf *sb, size_t need){
    while(sb->len + need + 1 > sb->cap){ sb->cap *= 2; sb->buf=realloc(sb->buf, sb->cap); }
}
static void sb_puts(SBuf *sb, const char *s){ size_t n=strlen(s); sb_grow(sb,n); memcpy(sb->buf+sb->len,s,n); sb->len+=n; sb->buf[sb->len]=0; }
static void sb_putc(SBuf *sb, char c){ sb_grow(sb,1); sb->buf[sb->len++]=c; sb->buf[sb->len]=0; }
static void sb_putf(SBuf *sb, const char *fmt, ...){
    char tmp[512]; va_list ap; va_start(ap,fmt);
    int n=vsnprintf(tmp,sizeof(tmp),fmt,ap); va_end(ap);
    if(n<0) return;
    if((size_t)n < sizeof(tmp)){ sb_puts(sb,tmp); }
    else { sb_grow(sb,n); va_start(ap,fmt); vsnprintf(sb->buf+sb->len,n+1,fmt,ap); va_end(ap); sb->len+=n; }
}
static void sb_json_str(SBuf *sb, const char *s, size_t len){
    sb_putc(sb,'"');
    for(size_t i=0;i<len;i++){
        unsigned char c=(unsigned char)s[i];
        if(c=='"') sb_puts(sb,"\\\"");
        else if(c=='\\') sb_puts(sb,"\\\\");
        else if(c=='\n') sb_puts(sb,"\\n");
        else if(c=='\r') sb_puts(sb,"\\r");
        else if(c=='\t') sb_puts(sb,"\\t");
        else if(c < 0x20) sb_putf(sb,"\\u%04x",c);
        else sb_putc(sb,(char)c);
    }
    sb_putc(sb,'"');
}

/* Instruction bit extraction (Lua 5.3 32-bit) */
#define INSP_OP(i)   ((int)((i) & 0x3F))
#define INSP_A(i)    ((int)(((i) >> 6) & 0xFF))
#define INSP_C(i)    ((int)(((i) >> 14) & 0x1FF))
#define INSP_B(i)    ((int)(((i) >> 23) & 0x1FF))
#define INSP_Bx(i)   ((int)(((i) >> 14) & 0x3FFFF))
#define INSP_sBx(i)  (INSP_Bx(i) - 131071)
#define INSP_Ax(i)   ((int)(((i) >> 6) & 0x3FFFFFF))

#define INSPECT_MAX_DEPTH 4
#define INSPECT_MAX_INSTRS 200
#define INSPECT_MAX_STR 120

static void inspect_proto(lua_State *L, int proto_idx, SBuf *sb, int depth) {
    int abs_p = lua_absindex(L, proto_idx);
    sb_puts(sb,"{");

    /* basic fields */
    lua_getfield(L, abs_p, "sizecode"); int sizecode = (int)lua_tointeger(L,-1); lua_pop(L,1);
    lua_getfield(L, abs_p, "sizek");    int sizek = (int)lua_tointeger(L,-1); lua_pop(L,1);
    lua_getfield(L, abs_p, "sizep");    int sizep = (int)lua_tointeger(L,-1); lua_pop(L,1);
    lua_getfield(L, abs_p, "numparams"); int numparams = (int)lua_tointeger(L,-1); lua_pop(L,1);
    lua_getfield(L, abs_p, "is_vararg"); int is_vararg = (int)lua_tointeger(L,-1); lua_pop(L,1);
    lua_getfield(L, abs_p, "linedefined"); int linedefined = (int)lua_tointeger(L,-1); lua_pop(L,1);

    sb_putf(sb,"\"sizecode\":%d,\"sizek\":%d,\"sizep\":%d,", sizecode, sizek, sizep);
    sb_putf(sb,"\"numparams\":%d,\"is_vararg\":%d,\"linedefined\":%d,", numparams, is_vararg, linedefined);

    /* constants */
    sb_puts(sb,"\"constants\":[");
    lua_getfield(L, abs_p, "k");
    if(lua_istable(L,-1)){
        for(int i=1;i<=sizek;i++){
            if(i>1) sb_putc(sb,',');
            lua_rawgeti(L,-1,i);
            int t = lua_type(L,-1);
            sb_puts(sb,"{\"idx\":"); sb_putf(sb,"%d",i-1); sb_puts(sb,",\"type\":\"");
            sb_puts(sb, lua_typename(L,t));
            sb_puts(sb,"\",\"value\":");
            if(t==LUA_TSTRING){
                size_t slen; const char *s = lua_tolstring(L,-1,&slen);
                size_t show = slen < INSPECT_MAX_STR ? slen : INSPECT_MAX_STR;
                sb_json_str(sb, s, show);
                if(slen > INSPECT_MAX_STR) sb_putf(sb,",\"truncated\":true,\"full_len\":%d",(int)slen);
            } else if(t==LUA_TNUMBER){
                if(lua_isinteger(L,-1)) sb_putf(sb,"%lld",(long long)lua_tointeger(L,-1));
                else sb_putf(sb,"%g",lua_tonumber(L,-1));
            } else if(t==LUA_TBOOLEAN){
                sb_puts(sb, lua_toboolean(L,-1) ? "true" : "false");
            } else if(t==LUA_TNIL){
                sb_puts(sb,"null");
            } else {
                sb_json_str(sb, lua_typename(L,t), strlen(lua_typename(L,t)));
            }
            sb_putc(sb,'}');
            lua_pop(L,1);
        }
    }
    lua_pop(L,1); /* k table */
    sb_puts(sb,"],");

    /* instructions (first N) */
    int show_instr = sizecode < INSPECT_MAX_INSTRS ? sizecode : INSPECT_MAX_INSTRS;
    sb_putf(sb,"\"instructions_show\":%d,\"instructions\":[", show_instr);
    lua_getfield(L, abs_p, "code");
    if(lua_istable(L,-1)){
        for(int i=1;i<=show_instr;i++){
            if(i>1) sb_putc(sb,',');
            lua_rawgeti(L,-1,i);
            unsigned int inst = (unsigned int)lua_tointeger(L,-1);
            lua_pop(L,1);
            int op = INSP_OP(inst);
            const char *opname = (op >= 0 && op < 48) ? INSPECT_OPNAMES[op] : "UNKNOWN";
            sb_putf(sb,"{\"pc\":%d,\"op\":\"%s\",\"opcode\":%d,\"a\":%d,\"b\":%d,\"c\":%d",
                i-1, opname, op, INSP_A(inst), INSP_B(inst), INSP_C(inst));
            /* add Bx/sBx/Ax for relevant opcodes */
            if(op==1 /*LOADK*/ || op==2 /*LOADKX*/ || op==25 /*UNM*/ || op==26 /*BNOT*/ ||
               op==27 /*NOT*/ || op==28 /*LEN*/ || op==37 /*TAILCALL*/){
                sb_putf(sb,",\"bx\":%d", INSP_Bx(inst));
            }
            if(op==30 /*JMP*/ || op==39 /*FORLOOP*/ || op==40 /*FORPREP*/ || op==42 /*TFORLOOP*/){
                sb_putf(sb,",\"sbx\":%d", INSP_sBx(inst));
            }
            if(op==40){ /* EXTRAARG-ish, actually op 40 is SETLIST? let me check: 40=SETLIST, 41=CLOSURE, 42=VARARG, 47=EXTRAARG */}
            sb_putc(sb,'}');
        }
        if(sizecode > INSPECT_MAX_INSTRS){
            sb_putf(sb,"],\"instructions_total\":%d,\"instructions_truncated\":true", sizecode);
        } else {
            sb_puts(sb,"]");
        }
    } else {
        sb_puts(sb,"]");
    }
    lua_pop(L,1); /* code table */

    /* debug info: locvars */
    lua_getfield(L, abs_p, "sizelocvars"); int sizelocvars = (int)lua_tointeger(L,-1); lua_pop(L,1);
    sb_putf(sb,",\"sizelocvars\":%d,\"locvars\":[", sizelocvars);
    lua_getfield(L, abs_p, "locvars");
    if(lua_istable(L,-1)){
        for(int i=1;i<=sizelocvars;i++){
            if(i>1) sb_putc(sb,',');
            lua_rawgeti(L,-1,i);
            if(lua_istable(L,-1)){
                lua_getfield(L,-1,"varname"); const char *vn = lua_tostring(L,-1); lua_pop(L,1);
                lua_getfield(L,-1,"startpc"); int spc = (int)lua_tointeger(L,-1); lua_pop(L,1);
                lua_getfield(L,-1,"endpc"); int epc = (int)lua_tointeger(L,-1); lua_pop(L,1);
                sb_puts(sb,"{\"idx\":"); sb_putf(sb,"%d",i-1); sb_puts(sb,",\"varname\":");
                sb_json_str(sb, vn ? vn : "null", vn ? strlen(vn) : 4);
                sb_putf(sb,",\"startpc\":%d,\"endpc\":%d}", spc, epc);
            } else {
                sb_puts(sb,"null");
            }
            lua_pop(L,1);
        }
    }
    lua_pop(L,1); /* locvars table */
    sb_putc(sb,']');

    /* debug info: lineinfo (first N) */
    lua_getfield(L, abs_p, "sizelineinfo"); int sizelineinfo = (int)lua_tointeger(L,-1); lua_pop(L,1);
    int show_li = sizelineinfo < 100 ? sizelineinfo : 100;
    sb_putf(sb,",\"sizelineinfo\":%d,\"lineinfo_show\":%d,\"lineinfo\":[", sizelineinfo, show_li);
    lua_getfield(L, abs_p, "lineinfo");
    if(lua_istable(L,-1)){
        for(int i=1;i<=show_li;i++){
            if(i>1) sb_putc(sb,',');
            lua_rawgeti(L,-1,i);
            sb_putf(sb,"%d",(int)lua_tointeger(L,-1));
            lua_pop(L,1);
        }
    }
    lua_pop(L,1); /* lineinfo table */
    if(sizelineinfo > 100) sb_puts(sb,"],\"lineinfo_truncated\":true");
    else sb_putc(sb,']');

    /* upvalues */
    lua_getfield(L, abs_p, "sizeupvalues"); int sizeupvalues = (int)lua_tointeger(L,-1); lua_pop(L,1);
    sb_putf(sb,",\"sizeupvalues\":%d,\"upvalues\":[", sizeupvalues);
    lua_getfield(L, abs_p, "upvalues");
    if(lua_istable(L,-1)){
        for(int i=1;i<=sizeupvalues;i++){
            if(i>1) sb_putc(sb,',');
            lua_rawgeti(L,-1,i);
            if(lua_istable(L,-1)){
                lua_getfield(L,-1,"name"); const char *un = lua_tostring(L,-1); lua_pop(L,1);
                lua_getfield(L,-1,"instack"); int uis = (int)lua_tointeger(L,-1); lua_pop(L,1);
                lua_getfield(L,-1,"idx"); int uidx = (int)lua_tointeger(L,-1); lua_pop(L,1);
                sb_puts(sb,"{\"idx\":"); sb_putf(sb,"%d",i-1); sb_puts(sb,",\"name\":");
                sb_json_str(sb, un ? un : "null", un ? strlen(un) : 4);
                sb_putf(sb,",\"instack\":%d,\"idx\":%d}", uis, uidx);
            } else {
                sb_puts(sb,"null");
            }
            lua_pop(L,1);
        }
    }
    lua_pop(L,1); /* upvalues table */
    sb_putc(sb,']');

    /* subprotos (recursive, depth-limited) */
    if(depth < INSPECT_MAX_DEPTH){
        sb_puts(sb,",\"subprotos\":[");
        lua_getfield(L, abs_p, "p");
        if(lua_istable(L,-1)){
            for(int i=1;i<=sizep;i++){
                if(i>1) sb_putc(sb,',');
                lua_rawgeti(L,-1,i);
                if(lua_isuserdata(L,-1)){
                    inspect_proto(L, -1, sb, depth+1);
                } else {
                    sb_puts(sb,"null");
                }
                lua_pop(L,1);
            }
        }
        lua_pop(L,1); /* p table */
        sb_putc(sb,']');
    } else {
        sb_putf(sb,",\"subprotos_omitted\":%d", sizep);
    }

    sb_putc(sb,'}');
}

EMSCRIPTEN_KEEPALIVE
char *wasm_inspect(int handle, int *out_len) {
    if (!g_L || !out_len || handle < 0) {
        set_error("wasm_inspect: invalid args");
        *out_len = 0;
        return NULL;
    }
    *out_len = 0;
    lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
    if (!lua_isuserdata(g_L, -1)) {
        lua_pop(g_L, 1);
        set_error("wasm_inspect: invalid handle");
        return NULL;
    }
    SBuf sb;
    sb_init(&sb);
    inspect_proto(g_L, -1, &sb, 0);
    lua_pop(g_L, 1);
    *out_len = (int)sb.len;
    g_errbuf[0] = '\0';
    return sb.buf; /* caller must free with wasm_free_dump */
}

/*===========================================================================
** Bytecode Editor API
**=========================================================================*/

/* Push proto.code table onto stack, return its index */
static int editor_get_code_table(lua_State *L, int handle) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, handle);
    if (!lua_isuserdata(L, -1)) { lua_pop(L, 1); return -1; }
    lua_getfield(L, -1, "code");
    lua_remove(L, -2); /* remove proto userdata */
    if (!lua_istable(L, -1)) { lua_pop(L, 1); return -1; }
    return lua_gettop(L);
}

static int editor_get_k_table(lua_State *L, int handle) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, handle);
    if (!lua_isuserdata(L, -1)) { lua_pop(L, 1); return -1; }
    lua_getfield(L, -1, "k");
    lua_remove(L, -2);
    if (!lua_istable(L, -1)) { lua_pop(L, 1); return -1; }
    return lua_gettop(L);
}

/* Auto-fix all JMP sBx offsets after instruction insertion/deletion.
   old_targets[i] = original target pc of JMP at instruction i (or -1 if not JMP).
   n = original instruction count.
   delta_map: for each original pc, what is the new pc? We compute by scanning.
   Actually simpler: recompute each JMP's target using old target, then map to new. */
static void editor_fix_jmp_offsets(lua_State *L, int code_idx, int *old_targets, int old_n, int *new_pos_map) {
    /* new_pos_map[old_pc] = new_pc (for instructions that survived) */
    for (int i = 0; i < old_n; i++) {
        if (old_targets[i] < 0) continue;
        /* this JMP was at old pc i, find its new pc */
        int new_j = new_pos_map[i];
        if (new_j < 0) continue; /* JMP was deleted */
        int old_target = old_targets[i];
        int new_target;
        if (old_target >= old_n) {
            /* target beyond end (e.g. jump to end+1 for return), map to end */
            new_target = new_pos_map[old_n - 1] + 1;
        } else if (old_target < 0) {
            new_target = old_target; /* negative offset (backward jump before start), keep */
        } else {
            new_target = new_pos_map[old_target];
            if (new_target < 0) new_target = old_target;
        }
        /* sBx = target - (new_j + 1) */
        int new_sbx = new_target - (new_j + 1);
        /* read instruction at new_j+1 (1-based) and update sBx */
        lua_rawgeti(L, code_idx, new_j + 1);
        unsigned int inst = (unsigned int)lua_tointeger(L, -1);
        lua_pop(L, 1);
        int op = INSP_OP(inst);
        if (op == 30 /*JMP*/ || op == 39 /*FORLOOP*/ || op == 40 /*FORPREP*/ || op == 42 /*TFORLOOP*/) {
            /* clear sBx field (bits 14-31) and set new */
            inst = (inst & 0x00003FFF) | ((unsigned int)(new_sbx + 131071) << 14);
            lua_pushinteger(L, (lua_Integer)inst);
            lua_rawseti(L, code_idx, new_j + 1);
        }
    }
}

EMSCRIPTEN_KEEPALIVE
int wasm_get_code_size(int handle) {
    if (!g_L || handle < 0) return -1;
    lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
    if (!lua_isuserdata(g_L, -1)) { lua_pop(g_L, 1); return -1; }
    lua_getfield(g_L, -1, "sizecode");
    int n = (int)lua_tointeger(g_L, -1);
    lua_pop(g_L, 2);
    return n;
}

EMSCRIPTEN_KEEPALIVE
int wasm_get_instruction(int handle, int pc) {
    if (!g_L || handle < 0 || pc < 0) return -1;
    int ci = editor_get_code_table(g_L, handle);
    if (ci < 0) return -1;
    lua_rawgeti(g_L, ci, pc + 1);
    int inst = (int)lua_tointeger(g_L, -1);
    lua_pop(g_L, 2); /* value + code table */
    return inst;
}

EMSCRIPTEN_KEEPALIVE
int wasm_set_instruction(int handle, int pc, int value) {
    if (!g_L || handle < 0 || pc < 0) { set_error("wasm_set_instruction: invalid args"); return -1; }
    int ci = editor_get_code_table(g_L, handle);
    if (ci < 0) { set_error("wasm_set_instruction: no code table"); return -1; }
    lua_pushinteger(g_L, (lua_Integer)(unsigned int)value);
    lua_rawseti(g_L, ci, pc + 1);
    lua_pop(g_L, 1); /* code table */
    g_errbuf[0] = '\0';
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int wasm_insert_instruction(int handle, int pc, int value) {
    if (!g_L || handle < 0 || pc < 0) { set_error("wasm_insert_instruction: invalid args"); return -1; }
    int ci = editor_get_code_table(g_L, handle);
    if (ci < 0) { set_error("wasm_insert_instruction: no code table"); return -1; }
    int old_n = (int)lua_rawlen(g_L, ci);

    /* record old JMP targets */
    int *old_targets = (int *)malloc(sizeof(int) * (old_n + 1));
    int *new_pos_map = (int *)malloc(sizeof(int) * (old_n + 1));
    for (int i = 0; i <= old_n; i++) { old_targets[i] = -1; new_pos_map[i] = i; }
    for (int i = 0; i < old_n; i++) {
        lua_rawgeti(g_L, ci, i + 1);
        unsigned int inst = (unsigned int)lua_tointeger(g_L, -1);
        lua_pop(g_L, 1);
        int op = INSP_OP(inst);
        if (op == 30 || op == 39 || op == 40 || op == 42) {
            old_targets[i] = i + 1 + INSP_sBx(inst);
        }
    }
    /* build new position map: instructions at >= pc shift by +1 */
    for (int i = 0; i <= old_n; i++) {
        new_pos_map[i] = (i >= pc) ? i + 1 : i;
    }

    /* shift instructions from old_n down to pc */
    for (int i = old_n; i > pc; i--) {
        lua_rawgeti(g_L, ci, i);
        lua_rawseti(g_L, ci, i + 1);
    }
    /* insert new instruction at pc+1 */
    lua_pushinteger(g_L, (lua_Integer)(unsigned int)value);
    lua_rawseti(g_L, ci, pc + 1);

    /* fix JMP offsets */
    editor_fix_jmp_offsets(g_L, ci, old_targets, old_n, new_pos_map);

    /* sync all tables to C arrays */
    lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
    luac_sync_proto(g_L, -1);
    lua_pop(g_L, 1);

    free(old_targets);
    free(new_pos_map);
    lua_pop(g_L, 1); /* code table */
    g_errbuf[0] = '\0';
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int wasm_delete_instruction(int handle, int pc) {
    if (!g_L || handle < 0 || pc < 0) { set_error("wasm_delete_instruction: invalid args"); return -1; }
    int ci = editor_get_code_table(g_L, handle);
    if (ci < 0) { set_error("wasm_delete_instruction: no code table"); return -1; }
    int old_n = (int)lua_rawlen(g_L, ci);
    if (pc >= old_n) { set_error("wasm_delete_instruction: pc out of range"); lua_pop(g_L,1); return -1; }

    int *old_targets = (int *)malloc(sizeof(int) * (old_n + 1));
    int *new_pos_map = (int *)malloc(sizeof(int) * (old_n + 1));
    for (int i = 0; i <= old_n; i++) { old_targets[i] = -1; new_pos_map[i] = i; }
    for (int i = 0; i < old_n; i++) {
        lua_rawgeti(g_L, ci, i + 1);
        unsigned int inst = (unsigned int)lua_tointeger(g_L, -1);
        lua_pop(g_L, 1);
        int op = INSP_OP(inst);
        if (op == 30 || op == 39 || op == 40 || op == 42) {
            old_targets[i] = i + 1 + INSP_sBx(inst);
        }
    }
    /* new position map: deleted pc maps to -1, instructions > pc shift -1 */
    for (int i = 0; i <= old_n; i++) {
        if (i == pc) new_pos_map[i] = -1;
        else if (i > pc) new_pos_map[i] = i - 1;
        else new_pos_map[i] = i;
    }

    /* shift instructions from pc+1 to old_n down by 1 */
    for (int i = pc + 1; i < old_n; i++) {
        lua_rawgeti(g_L, ci, i + 1);
        lua_rawseti(g_L, ci, i);
    }
    /* clear last */
    lua_pushnil(g_L);
    lua_rawseti(g_L, ci, old_n);

    editor_fix_jmp_offsets(g_L, ci, old_targets, old_n, new_pos_map);

    /* sync all tables to C arrays */
    lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
    luac_sync_proto(g_L, -1);
    lua_pop(g_L, 1);

    free(old_targets);
    free(new_pos_map);
    lua_pop(g_L, 1);
    g_errbuf[0] = '\0';
    return 0;
}

/* ---- Constants ---- */

EMSCRIPTEN_KEEPALIVE
int wasm_get_k_size(int handle) {
    if (!g_L || handle < 0) return -1;
    lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
    if (!lua_isuserdata(g_L, -1)) { lua_pop(g_L, 1); return -1; }
    lua_getfield(g_L, -1, "sizek");
    int n = (int)lua_tointeger(g_L, -1);
    lua_pop(g_L, 2);
    return n;
}

/* Returns constant type as int: 0=nil,1=boolean,2=number,3=string,4=other */
EMSCRIPTEN_KEEPALIVE
int wasm_get_constant_type(int handle, int idx) {
    if (!g_L || handle < 0 || idx < 0) return -1;
    int ki = editor_get_k_table(g_L, handle);
    if (ki < 0) return -1;
    lua_rawgeti(g_L, ki, idx + 1);
    int t = lua_type(g_L, -1);
    lua_pop(g_L, 2);
    int result = 4;
    if (t == LUA_TNIL) result = 0;
    else if (t == LUA_TBOOLEAN) result = 1;
    else if (t == LUA_TNUMBER) result = 2;
    else if (t == LUA_TSTRING) result = 3;
    return result;
}

EMSCRIPTEN_KEEPALIVE
double wasm_get_constant_number(int handle, int idx) {
    if (!g_L || handle < 0 || idx < 0) return 0;
    int ki = editor_get_k_table(g_L, handle);
    if (ki < 0) return 0;
    lua_rawgeti(g_L, ki, idx + 1);
    double v = lua_tonumber(g_L, -1);
    lua_pop(g_L, 2);
    return v;
}

EMSCRIPTEN_KEEPALIVE
const char *wasm_get_constant_string(int handle, int idx) {
    static char buf[8192];
    buf[0] = '\0';
    if (!g_L || handle < 0 || idx < 0) return buf;
    int ki = editor_get_k_table(g_L, handle);
    if (ki < 0) return buf;
    lua_rawgeti(g_L, ki, idx + 1);
    if (lua_isstring(g_L, -1)) {
        size_t len;
        const char *s = lua_tolstring(g_L, -1, &len);
        if (len >= sizeof(buf)) len = sizeof(buf) - 1;
        memcpy(buf, s, len);
        buf[len] = '\0';
    }
    lua_pop(g_L, 2);
    return buf;
}

EMSCRIPTEN_KEEPALIVE
int wasm_get_constant_bool(int handle, int idx) {
    if (!g_L || handle < 0 || idx < 0) return 0;
    int ki = editor_get_k_table(g_L, handle);
    if (ki < 0) return 0;
    lua_rawgeti(g_L, ki, idx + 1);
    int v = lua_toboolean(g_L, -1);
    lua_pop(g_L, 2);
    return v;
}

EMSCRIPTEN_KEEPALIVE
int wasm_set_constant_number(int handle, int idx, double value) {
    if (!g_L || handle < 0 || idx < 0) { set_error("invalid args"); return -1; }
    int ki = editor_get_k_table(g_L, handle);
    if (ki < 0) { set_error("no k table"); return -1; }
    lua_pushnumber(g_L, value);
    lua_rawseti(g_L, ki, idx + 1);
    lua_pop(g_L, 1);
    g_errbuf[0] = '\0';
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int wasm_set_constant_string(int handle, int idx, const char *s, int len) {
    if (!g_L || handle < 0 || idx < 0 || !s) { set_error("invalid args"); return -1; }
    int ki = editor_get_k_table(g_L, handle);
    if (ki < 0) { set_error("no k table"); return -1; }
    lua_pushlstring(g_L, s, (size_t)len);
    lua_rawseti(g_L, ki, idx + 1);
    lua_pop(g_L, 1);
    g_errbuf[0] = '\0';
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int wasm_set_constant_bool(int handle, int idx, int value) {
    if (!g_L || handle < 0 || idx < 0) { set_error("invalid args"); return -1; }
    int ki = editor_get_k_table(g_L, handle);
    if (ki < 0) { set_error("no k table"); return -1; }
    lua_pushboolean(g_L, value ? 1 : 0);
    lua_rawseti(g_L, ki, idx + 1);
    lua_pop(g_L, 1);
    g_errbuf[0] = '\0';
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int wasm_set_constant_nil(int handle, int idx) {
    if (!g_L || handle < 0 || idx < 0) { set_error("invalid args"); return -1; }
    int ki = editor_get_k_table(g_L, handle);
    if (ki < 0) { set_error("no k table"); return -1; }
    lua_pushnil(g_L);
    lua_rawseti(g_L, ki, idx + 1);
    lua_pop(g_L, 1);
    g_errbuf[0] = '\0';
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int wasm_add_constant_number(int handle, double value) {
    if (!g_L || handle < 0) { set_error("invalid args"); return -1; }
    int ki = editor_get_k_table(g_L, handle);
    if (ki < 0) { set_error("no k table"); return -1; }
    int n = (int)lua_rawlen(g_L, ki);
    lua_pushnumber(g_L, value);
    lua_rawseti(g_L, ki, n + 1);
    /* sync all tables to C arrays */
    lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
    luac_sync_proto(g_L, -1);
    lua_pop(g_L, 1);
    lua_pop(g_L, 1); /* k table */
    g_errbuf[0] = '\0';
    return n; /* new index (0-based) */
}

EMSCRIPTEN_KEEPALIVE
int wasm_add_constant_string(int handle, const char *s, int len) {
    if (!g_L || handle < 0 || !s) { set_error("invalid args"); return -1; }
    int ki = editor_get_k_table(g_L, handle);
    if (ki < 0) { set_error("no k table"); return -1; }
    int n = (int)lua_rawlen(g_L, ki);
    lua_pushlstring(g_L, s, (size_t)len);
    lua_rawseti(g_L, ki, n + 1);
    /* sync all tables to C arrays */
    lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
    luac_sync_proto(g_L, -1);
    lua_pop(g_L, 1);
    lua_pop(g_L, 1);
    g_errbuf[0] = '\0';
    return n;
}

/* Remove constant at idx, shift all > idx down by 1, fix LOADK/LOADKX references */
EMSCRIPTEN_KEEPALIVE
int wasm_remove_constant(int handle, int idx) {
    if (!g_L || handle < 0 || idx < 0) { set_error("invalid args"); return -1; }
    int ki = editor_get_k_table(g_L, handle);
    if (ki < 0) { set_error("no k table"); return -1; }
    int n = (int)lua_rawlen(g_L, ki);
    if (idx >= n) { lua_pop(g_L, 1); set_error("idx out of range"); return -1; }

    /* shift constants down */
    for (int i = idx + 1; i < n; i++) {
        lua_rawgeti(g_L, ki, i + 1);
        lua_rawseti(g_L, ki, i);
    }
    lua_pushnil(g_L);
    lua_rawseti(g_L, ki, n);

    /* fix LOADK (op=1) Bx and LOADKX (op=2) + EXTRAARG (op=47) Ax references */
    int ci = editor_get_code_table(g_L, handle);
    if (ci >= 0) {
        int code_n = (int)lua_rawlen(g_L, ci);
        for (int i = 0; i < code_n; i++) {
            lua_rawgeti(g_L, ci, i + 1);
            unsigned int inst = (unsigned int)lua_tointeger(g_L, -1);
            lua_pop(g_L, 1);
            int op = INSP_OP(inst);
            if (op == 1 /*LOADK*/) {
                int bx = INSP_Bx(inst);
                if (bx > idx) {
                    inst = (inst & 0x00003FFF) | ((unsigned int)(bx - 1) << 14);
                    lua_pushinteger(g_L, (lua_Integer)inst);
                    lua_rawseti(g_L, ci, i + 1);
                }
            } else if (op == 2 /*LOADKX*/) {
                if (i + 1 < code_n) {
                    lua_rawgeti(g_L, ci, i + 2);
                    unsigned int ea_inst = (unsigned int)lua_tointeger(g_L, -1);
                    lua_pop(g_L, 1);
                    if (INSP_OP(ea_inst) == 47 /*EXTRAARG*/) {
                        int ax = INSP_Ax(ea_inst);
                        if (ax > idx) {
                            ea_inst = (ea_inst & 0x0000003F) | ((unsigned int)(ax - 1) << 6);
                            lua_pushinteger(g_L, (lua_Integer)ea_inst);
                            lua_rawseti(g_L, ci, i + 2);
                        }
                    }
                }
            }
        }
        /* sync all tables to C arrays */
        lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
        luac_sync_proto(g_L, -1);
        lua_pop(g_L, 1);
        lua_pop(g_L, 1); /* code table */
    }

    /* sync all tables to C arrays */
    lua_rawgeti(g_L, LUA_REGISTRYINDEX, handle);
    luac_sync_proto(g_L, -1);
    lua_pop(g_L, 1);
    lua_pop(g_L, 1); /* k table */
    g_errbuf[0] = '\0';
    return 0;
}
