path = r'E:\LuaRes\luaclib\obf_util.h'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'int obf_add_subproto(luac_Proto *p, luac_Proto *sub);',
    'int obf_add_subproto(lua_State *L, luac_Proto *p, luac_Proto *sub);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
