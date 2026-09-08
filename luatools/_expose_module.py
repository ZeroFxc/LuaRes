p = r'E:\LuaRes\web\app.js'
s = open(p, encoding='utf-8').read()
old = '''    });
    wasmReady = true;'''
new = '''    });
    window._Module = Module;
    wasmReady = true;'''
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('exposed Module')
