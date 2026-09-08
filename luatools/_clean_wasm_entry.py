p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

# Remove debug buffer and functions
old_dbg = '''static char g_errbuf[2048];
static char g_dbgbuf[16384];
static int g_dbgpos = 0;
static void dbg_log(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(g_dbgbuf + g_dbgpos, sizeof(g_dbgbuf) - g_dbgpos, fmt, ap);
    va_end(ap);
    if (n > 0) g_dbgpos += n;
    if (g_dbgpos > (int)sizeof(g_dbgbuf) - 200) g_dbgpos = sizeof(g_dbgbuf) - 200;
}
EMSCRIPTEN_KEEPALIVE
const char *wasm_get_debug(void) { return g_dbgbuf; }
EMSCRIPTEN_KEEPALIVE
void wasm_clear_debug(void) { g_dbgpos = 0; g_dbgbuf[0] = 0; }

/* Registry key'''
new_dbg = '''static char g_errbuf[2048];

/* Registry key'''
s = s.replace(old_dbg, new_dbg, 1)

# Remove first_byte debug from wasm_load
old_load = '''    unsigned char first_byte = raw[0];
    set_error("wasm_load: first_byte=0x%02X raw_len=%zu input_len=%d", first_byte, raw_len, len);
    dbg_log("[wasm_load] input_len=%d raw_len=%zu first_byte=0x%02X\\n", len, raw_len, first_byte);
    /* dump first 16 bytes */
    {
        char hex[128]; int hp = 0;
        for (int i = 0; i < 16 && i < (int)raw_len; i++) hp += sprintf(hex + hp, "%02X ", raw[i]);
        dbg_log("[wasm_load] first16: %s\\n", hex);
    }

    lua_getglobal'''
new_load = '''    lua_getglobal'''
s = s.replace(old_load, new_load, 1)

# Remove "keep g_errbuf for debugging" comment
old_ref = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    /* keep g_errbuf for debugging (set earlier with first_byte) */
    return ref;'''
new_ref = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    g_errbuf[0] = '\\0';
    return ref;'''
s = s.replace(old_ref, new_ref, 1)

# Remove #include <stdarg.h> if dbg_log was the only user (set_error still uses it)
# Keep stdarg.h because set_error uses va_list

open(p, 'w', encoding='utf-8').write(s)
print('removed all debug code from wasm_entry.c')
