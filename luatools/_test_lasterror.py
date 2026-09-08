p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

# Modify wasm_last_error to return fixed string for testing
old = '''const char *wasm_last_error(void) { return g_errbuf; }'''
new = '''const char *wasm_last_error(void) { return "TEST_FIXED_STRING"; }'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('wasm_last_error returns fixed string')
