path = r'E:\LuaRes\luaclib\str_encrypt.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old = '''    luac_Proto *dec_func = obf_compile_subproto(L, DECRYPT_SRC);
    fprintf(stderr, "DBG: returned dec_func=%p\\n", (void*)dec_func); fflush(stderr);
    if (!dec_func) { fprintf(stderr, "DBG: dec_func NULL\\n"); return 0; }
    fprintf(stderr, "DBG: dec_func created, maxstack=%d\\n", dec_func->maxstacksize); fflush(stderr);'''

new = '''    luac_Proto *dec_func = NULL;
    if (!obf_compile_subproto(L, DECRYPT_SRC, &dec_func)) return 0;
    fprintf(stderr, "DBG: dec_func=%p maxstack=%d\\n", (void*)dec_func, dec_func->maxstacksize); fflush(stderr);'''

if old in content:
    content = content.replace(old, new, 1)
    print('replaced')
else:
    print('NOT FOUND')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
