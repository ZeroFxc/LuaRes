p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()
old = '    "upvalue_promote_c";'
new = '    "upvalue_promote_c,"\n    "block_clone_c";'
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('OK')
