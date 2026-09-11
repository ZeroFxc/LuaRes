path = r'E:\LuaRes\luaclib\str_encrypt.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the decrypt proto creation logic
old = '''    /* create decrypt proto */
    luac_Proto *dec_proto = obf_compile_source(L, DECRYPT_SRC);
    if (!dec_proto) return 0;
    /* extract the actual decrypt function (first sub-proto of main) */
    luac_Proto *dec_func = NULL;
    if (dec_proto->p && dec_proto->sizep >= 1) {
        dec_func = dec_proto->p[0];
        /* fix upvalue */
        if (dec_func->upval_instack && dec_func->sizeupvalues > 0) {
            dec_func->upval_instack[0] = 0;
            dec_func->upval_idx[0] = 0;
        }
        dec_proto->p[0] = NULL; /* detach */
        dec_proto->sizep = 0;
    }
    free(dec_proto);
    if (!dec_func) return 0;

    int dec_idx = obf_add_subproto(L, p, dec_func);'''

new = '''    /* create decrypt proto (compiles source, returns first sub-proto userdata on stack) */
    luac_Proto *dec_func = obf_compile_subproto(L, DECRYPT_SRC);
    if (!dec_func) return 0;

    int dec_idx = obf_add_subproto(L, p, dec_func);'''

if old in content:
    content = content.replace(old, new, 1)
    print('replaced decrypt proto creation')
else:
    print('pattern NOT FOUND')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
