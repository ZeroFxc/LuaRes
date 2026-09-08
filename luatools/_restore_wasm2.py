p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

# Restore wasm_last_error
old = '''const char *wasm_last_error(void) { return "TEST_FIXED_STRING"; }'''
new = '''const char *wasm_last_error(void) { return g_errbuf; }'''
s = s.replace(old, new, 1)

# Restore g_errbuf test to first_byte debug
old2 = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    g_errbuf[0] = 'X'; g_errbuf[1] = '\\0'; /* DEBUG: test g_errbuf */
    return ref;'''
new2 = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    /* keep g_errbuf for debugging (set earlier with first_byte) */
    return ref;'''
s = s.replace(old2, new2, 1)

open(p, 'w', encoding='utf-8').write(s)
print('restored wasm_last_error and g_errbuf')
