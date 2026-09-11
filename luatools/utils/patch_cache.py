import os, re

modules = [
    'str_encrypt.c', 'destr_encrypt.c',
    'const_hide.c', 'deconst_hide.c',
    'const_shuffle.c',
    'bool_obfuscate.c', 'num_obfuscate.c',
    'junk_jmp.c', 'junk_loadk.c', 'junk_move.c',
    'op48_junk.c', 'opaque_predicate.c',
    'table_obfuscate.c', 'detable_obfuscate.c',
    'instruction_mutate.c',
]

base = r'E:\LuaRes\luaclib'
for fname in modules:
    path = os.path.join(base, fname)
    s = open(path, encoding='utf-8').read()
    # Add cache invalidation before each lua_pushinteger in the _process function
    # Simple approach: add right after obf_check_proto line
    old = 'luac_Proto *p = obf_check_proto(L);'
    new = 'luac_Proto *p = obf_check_proto(L);\n    obf_invalidate_code_cache(L, p);'
    if old in s and 'obf_invalidate_code_cache' not in s:
        s = s.replace(old, new, 1)
        open(path, 'w', encoding='utf-8').write(s)
        print(f'  patched {fname}')
    else:
        print(f'  skip {fname} (already patched or pattern not found)')
print('done')
