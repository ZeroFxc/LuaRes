p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

old = '''int wasm_init(void) {
    if (g_L) return 0;'''

new = '''int wasm_init(void) {
    fprintf(stderr, "[WASM_ENTRY] wasm_init called\\n");
    if (g_L) return 0;'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('wasm_init debug added')
