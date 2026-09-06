path = r'E:\LuaRes\luaclib\obf_util.h'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'luac_Proto *obf_compile_source(lua_State *L, const char *src);',
    'luac_Proto *obf_compile_subproto(lua_State *L, const char *src);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
