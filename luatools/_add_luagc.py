p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

# 1. wasm_load: add lua_gc before return
old1 = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    g_errbuf[0] = '\\0';
    return ref;
}

EMSCRIPTEN_KEEPALIVE
int wasm_apply'''
new1 = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    g_errbuf[0] = '\\0';
    lua_gc(g_L, LUA_GCCOLLECT, 0);
    return ref;
}

EMSCRIPTEN_KEEPALIVE
int wasm_apply'''
s = s.replace(old1, new1, 1)

# 2. wasm_vm_embed: add lua_gc before return
old2 = '''    *out_len = (int)src_len;
    g_errbuf[0] = '\\0';
    return src;
}

EMSCRIPTEN_KEEPALIVE
void wasm_free'''
new2 = '''    *out_len = (int)src_len;
    g_errbuf[0] = '\\0';
    lua_gc(g_L, LUA_GCCOLLECT, 0);
    return src;
}

EMSCRIPTEN_KEEPALIVE
void wasm_free'''
s = s.replace(old2, new2, 1)

# 3. wasm_dump: add lua_gc before return
old3 = '''    *out_len = (int)len;
    g_errbuf[0] = '\\0';
    return buf;
}

EMSCRIPTEN_KEEPALIVE
char *wasm_vm_embed'''
new3 = '''    *out_len = (int)len;
    g_errbuf[0] = '\\0';
    lua_gc(g_L, LUA_GCCOLLECT, 0);
    return buf;
}

EMSCRIPTEN_KEEPALIVE
char *wasm_vm_embed'''
s = s.replace(old3, new3, 1)

open(p, 'w', encoding='utf-8').write(s)
print('added lua_gc to wasm_load, wasm_dump, wasm_vm_embed')
