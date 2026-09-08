p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

# Store first byte before free
old1 = '''    dbg_log("[wasm_load] input_len=%d raw_len=%zu first_byte=0x%02X\\n", len, raw_len, raw[0]);'''
new1 = '''    unsigned char first_byte = raw[0];
    dbg_log("[wasm_load] input_len=%d raw_len=%zu first_byte=0x%02X\\n", len, raw_len, first_byte);'''
s = s.replace(old1, new1, 1)

# Use first_byte in set_error instead of clearing
old2 = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    /* DEBUG: store first byte in error buffer for inspection */
    set_error("wasm_load OK: first_byte=0x%02X raw_len=%zu input_len=%d", raw[0], raw_len, len);
    return ref;'''
new2 = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    set_error("wasm_load OK: first_byte=0x%02X raw_len=%zu input_len=%d", first_byte, raw_len, len);
    return ref;'''
s = s.replace(old2, new2, 1)

open(p, 'w', encoding='utf-8').write(s)
print('fixed first_byte storage')
