path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix p_tbl check in obf_add_subproto
content = content.replace(
    '    if (p->p_tbl != 0) {',
    '    if (p->p_tbl != LUA_NOREF) {'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
