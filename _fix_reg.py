p = r'E:\LuaRes\luaclib\obf_register.c'
s = open(p, encoding='utf-8').read()
old = '    {"block_clone_c", block_clone_process},\n    {"srand", obf_srand_lua},'
new = '    {"block_clone_c", block_clone_process},\n    {"cfg_shuffle_c", cfg_shuffle_process},\n    {"srand", obf_srand_lua},'
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('done')
