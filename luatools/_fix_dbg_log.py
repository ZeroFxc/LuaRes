p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

old = '''static lua_State *g_L = NULL;
static char g_errbuf[2048];'''

new = '''static lua_State *g_L = NULL;
static char g_errbuf[2048];
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
void wasm_clear_debug(void) { g_dbgpos = 0; g_dbgbuf[0] = 0; }'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('dbg_log defined correctly')
