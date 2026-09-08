p = r'E:\LuaRes\luaclib\obf_register.c'
s = open(p, encoding='utf-8').read()
old = '    {"upvalue_promote_c", upvalue_promote_process},\n    {"srand", obf_srand_lua},'
new = '    {"upvalue_promote_c", upvalue_promote_process},\n    {"block_clone_c", block_clone_process},\n    {"srand", obf_srand_lua},'
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('OK')
