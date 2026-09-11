path = r'E:\LuaRes\luaclib\str_encrypt.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'int dec_idx = obf_add_subproto(p, dec_func);',
    'int dec_idx = obf_add_subproto(L, p, dec_func);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
