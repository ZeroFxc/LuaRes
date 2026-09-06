path = r'E:\LuaRes\luaclib\str_encrypt.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '    luac_Proto *dec_func = obf_compile_subproto(L, DECRYPT_SRC);\n    if (!dec_func) { fprintf(stderr, "DBG: dec_func NULL\\n"); return 0; }',
    '    luac_Proto *dec_func = obf_compile_subproto(L, DECRYPT_SRC);\n    fprintf(stderr, "DBG: returned dec_func=%p\\n", (void*)dec_func); fflush(stderr);\n    if (!dec_func) { fprintf(stderr, "DBG: dec_func NULL\\n"); return 0; }'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
