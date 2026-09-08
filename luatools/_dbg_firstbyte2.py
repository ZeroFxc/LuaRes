p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

# After normalize_to_bytecode, store first byte in g_errbuf and DON'T clear it
old = '''    size_t raw_len = 0;
    unsigned char *raw = normalize_to_bytecode(data, len, &raw_len);
    if (!raw) return LUA_NOREF;
    unsigned char first_byte = raw[0];
    dbg_log("[wasm_load] input_len=%d raw_len=%zu first_byte=0x%02X\\n", len, raw_len, first_byte);'''

new = '''    size_t raw_len = 0;
    unsigned char *raw = normalize_to_bytecode(data, len, &raw_len);
    if (!raw) return LUA_NOREF;
    unsigned char first_byte = raw[0];
    set_error("wasm_load: first_byte=0x%02X raw_len=%zu input_len=%d", first_byte, raw_len, len);
    dbg_log("[wasm_load] input_len=%d raw_len=%zu first_byte=0x%02X\\n", len, raw_len, first_byte);'''

s = s.replace(old, new, 1)

# Don't clear g_errbuf at end
old2 = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    g_errbuf[0] = '\\0';
    return ref;
}

EMSCRIPTEN_KEEPALIVE
int wasm_apply'''

new2 = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    /* keep g_errbuf for debugging */
    return ref;
}

EMSCRIPTEN_KEEPALIVE
int wasm_apply'''

s = s.replace(old2, new2, 1)

open(p, 'w', encoding='utf-8').write(s)
print('debug first byte in g_errbuf, no clear')
