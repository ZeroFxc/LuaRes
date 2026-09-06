path = r'E:\LuaRes\luaclib\str_encrypt.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace str_encrypt_process to do two-pass: collect then process
old = '''int str_encrypt_process(lua_State *L) {
    fprintf(stderr, "DBG: str_encrypt_process entry\\n"); fflush(stderr);
    luac_Proto *p = obf_check_proto(L);
    fprintf(stderr, "DBG: got proto p=%p\\n", (void*)p); fflush(stderr);
    obf_srand((unsigned int)time(NULL));
    fprintf(stderr, "DBG: srand done\\n"); fflush(stderr);

    int count = 0;
    luac_Proto *stack[4096];
    int sp = 0;
    stack[sp++] = p;
    while (sp > 0) {
        luac_Proto *cur = stack[--sp];
        fprintf(stderr, "DBG: processing cur=%p sizecode=%d\\n", (void*)cur, cur->sizecode); fflush(stderr);
        count += encrypt_function(L, cur);
        if (cur->p) {
            for (int j = cur->sizep - 1; j >= 0; j--) {
                stack[sp++] = cur->p[j];
            }
        }
    }
    lua_pushinteger(L, count);
    return 1;
}'''

new = '''int str_encrypt_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_srand((unsigned int)time(NULL));

    /* two-pass: collect all protos first, then process.
       Newly added decrypt sub-protos must NOT be processed. */
    luac_Proto *list[8192];
    int list_count = 0;
    luac_Proto *stack[8192];
    int sp = 0;
    stack[sp++] = p;
    while (sp > 0 && list_count < 8192) {
        luac_Proto *cur = stack[--sp];
        list[list_count++] = cur;
        if (cur->p) {
            for (int j = cur->sizep - 1; j >= 0; j--) {
                stack[sp++] = cur->p[j];
            }
        }
    }

    int count = 0;
    for (int i = 0; i < list_count; i++) {
        count += encrypt_function(L, list[i]);
    }
    lua_pushinteger(L, count);
    return 1;
}'''

if old in content:
    content = content.replace(old, new, 1)
    print('replaced')
else:
    print('NOT FOUND')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
