p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()
old = '    lua_pushboolean(g_L, 0);\n    free(raw);'
new = '    lua_pushboolean(g_L, 1); /* DEBUG: force encrypted */\n    free(raw);'
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('force_encrypted=true')
