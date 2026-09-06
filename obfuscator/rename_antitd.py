import os, glob

# 1. Rename files
os.rename(r'E:\LuaRes\luatools\forward\antidec.lua', r'E:\LuaRes\luatools\forward\antidec.lua')
os.rename(r'E:\LuaRes\luatools\reverse\fix_antidec.lua', r'E:\LuaRes\luatools\reverse\fix_antidec.lua')
print('files renamed')

# 2. Update all references in .lua and .py files
files = []
for root, dirs, fnames in os.walk(r'E:\LuaRes'):
    if '.git' in root: continue
    for fn in fnames:
        if fn.endswith(('.lua', '.py', '.bat')):
            files.append(os.path.join(root, fn))

for f in files:
    with open(f, 'rb') as fh:
        content = fh.read()
    original = content
    content = content.replace(b'antidec', b'antidec')
    content = content.replace(b'fix_antidec', b'fix_antidec')
    content = content.replace(b'fix_antidec', b'fix_antidec')  # already correct
    if content != original:
        with open(f, 'wb') as fh:
            fh.write(content)
        print(f'updated: {f}')
