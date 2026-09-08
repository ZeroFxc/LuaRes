p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

old = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    g_errbuf[0] = '\\0';
    return ref;
}

EMSCRIPTEN_KEEPALIVE
int wasm_apply'''

new = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    /* DEBUG: store first byte in error buffer for inspection */
    set_error("wasm_load OK: first_byte=0x%02X raw_len=%zu input_len=%d", raw[0], raw_len, len);
    return ref;
}

EMSCRIPTEN_KEEPALIVE
int wasm_apply'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('debug first byte in g_errbuf')
