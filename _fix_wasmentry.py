p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()
s = s.replace(
    '    "block_clone_c";',
    '    "block_clone_c,"\n    "cfg_shuffle_c";'
)
open(p, 'w', encoding='utf-8').write(s)
print('done')
