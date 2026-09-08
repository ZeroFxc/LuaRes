p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

old = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    /* keep g_errbuf for debugging */
    return ref;
}

EMSCRIPTEN_KEEPALIVE
int wasm_apply'''

new = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    g_errbuf[0] = 'X'; g_errbuf[1] = '\\0'; /* DEBUG: test g_errbuf */
    return ref;
}

EMSCRIPTEN_KEEPALIVE
int wasm_apply'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('g_errbuf test')
