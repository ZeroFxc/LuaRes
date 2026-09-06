import os, glob

luaclib = r'E:\LuaRes\luaclib'
count = 0
for f in glob.glob(os.path.join(luaclib, '*.c')):
    with open(f, 'r', encoding='utf-8') as fh:
        src = fh.read()
    if 'obf_invalidate_code_cache(L, p)' in src:
        src = src.replace('obf_invalidate_code_cache(L, p)', 'obf_invalidate_all_caches(L, p)')
        with open(f, 'w', encoding='utf-8') as fh:
            fh.write(src)
        print(f'patched: {os.path.basename(f)}')
        count += 1
print(f'total patched: {count}')
