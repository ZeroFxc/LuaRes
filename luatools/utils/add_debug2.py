path = r'E:\LuaRes\luaclib\str_encrypt.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'int str_encrypt_process(lua_State *L) {\n    luac_Proto *p = obf_check_proto(L);',
    'int str_encrypt_process(lua_State *L) {\n    fprintf(stderr, "DBG: str_encrypt_process entry\\n"); fflush(stderr);\n    luac_Proto *p = obf_check_proto(L);\n    fprintf(stderr, "DBG: got proto p=%p\\n", (void*)p); fflush(stderr);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
