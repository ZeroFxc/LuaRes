import os, glob

old = b'E:/LuaRes/luatools/?.lua'
new = b'E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/reverse/?.lua;E:/LuaRes/luatools/utils/?.lua'

for f in glob.glob(r'E:\LuaRes\obfuscator\*.lua'):
    with open(f, 'rb') as fh:
        content = fh.read()
    if old in content:
        content = content.replace(old, new)
        with open(f, 'wb') as fh:
            fh.write(content)
        print(f'updated: {os.path.basename(f)}')
