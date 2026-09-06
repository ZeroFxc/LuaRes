path = r'E:\LuaRes\luaclib\str_encrypt.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add debug prints at key points in encrypt_function
content = content.replace(
    'static int encrypt_function(lua_State *L, luac_Proto *p) {',
    'static int encrypt_function(lua_State *L, luac_Proto *p) {\n    fprintf(stderr, "DBG: encrypt_function start, sizecode=%d sizek=%d\\n", p->sizecode, p->sizek);'
)

content = content.replace(
    '    if (enc_count == 0) return 0;',
    '    if (enc_count == 0) { fprintf(stderr, "DBG: no strings\\n"); return 0; }'
)

content = content.replace(
    '    if (loadk_count == 0) return 0;',
    '    if (loadk_count == 0) { fprintf(stderr, "DBG: no loadk\\n"); return 0; }'
)

content = content.replace(
    '    /* create decrypt proto (compiles source, returns first sub-proto userdata on stack) */',
    '    fprintf(stderr, "DBG: creating decrypt proto\\n");\n    /* create decrypt proto (compiles source, returns first sub-proto userdata on stack) */'
)

content = content.replace(
    '    if (!dec_func) return 0;',
    '    if (!dec_func) { fprintf(stderr, "DBG: dec_func NULL\\n"); return 0; }\n    fprintf(stderr, "DBG: dec_func created, maxstack=%d\\n", dec_func->maxstacksize);'
)

content = content.replace(
    '    int dec_idx = obf_add_subproto(L, p, dec_func);',
    '    fprintf(stderr, "DBG: adding subproto\\n");\n    int dec_idx = obf_add_subproto(L, p, dec_func);\n    fprintf(stderr, "DBG: subproto added idx=%d\\n", dec_idx);'
)

content = content.replace(
    '    /* build new code */',
    '    fprintf(stderr, "DBG: building new code\\n");\n    /* build new code */'
)

content = content.replace(
    '    free(p->code);\n    p->code = new_code;',
    '    fprintf(stderr, "DBG: replacing code old_len=%d new_len=%d\\n", old_len, new_len);\n    free(p->code);\n    p->code = new_code;'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
