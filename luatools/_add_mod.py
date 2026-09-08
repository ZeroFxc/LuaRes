p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()
old = '    "condition_split_c,"\n    "loop_restructure_c";'
new = '    "condition_split_c,"\n    "loop_restructure_c,"\n    "integrity_check_c";'
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('done')
