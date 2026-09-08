p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

# Add global debug buffer after g_errbuf
old = '''static char g_errbuf[1024];'''
new = '''static char g_errbuf[1024];
static char g_dbgbuf[8192];
static int g_dbgpos = 0;
static void dbg_log(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(g_dbgbuf + g_dbgpos, sizeof(g_dbgbuf) - g_dbgpos, fmt, ap);
    va_end(ap);
    if (n > 0) g_dbgpos += n;
    if (g_dbgpos > (int)sizeof(g_dbgbuf) - 100) g_dbgpos = sizeof(g_dbgbuf) - 100;
}
EMSCRIPTEN_KEEPALIVE
const char *wasm_get_debug(void) { return g_dbgbuf; }
EMSCRIPTEN_KEEPALIVE
void wasm_clear_debug(void) { g_dbgpos = 0; g_dbgbuf[0] = 0; }'''

s = s.replace(old, new, 1)

# Add debug in wasm_load after normalize_to_bytecode
old2 = '''    size_t raw_len = 0;
    unsigned char *raw = normalize_to_bytecode(data, len, &raw_len);
    if (!raw) return LUA_NOREF;'''
new2 = '''    size_t raw_len = 0;
    unsigned char *raw = normalize_to_bytecode(data, len, &raw_len);
    if (!raw) return LUA_NOREF;
    dbg_log("[wasm_load] input_len=%d raw_len=%zu first_byte=0x%02X\\n", len, raw_len, raw[0]);
    /* dump first 16 bytes */
    {
        char hex[128]; int hp = 0;
        for (int i = 0; i < 16 && i < (int)raw_len; i++) hp += sprintf(hex + hp, "%02X ", raw[i]);
        dbg_log("[wasm_load] first16: %s\\n", hex);
    }'''

s = s.replace(old2, new2, 1)

open(p, 'w', encoding='utf-8').write(s)
print('debug buffer added')
