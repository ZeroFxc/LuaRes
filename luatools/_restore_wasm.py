p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

# Restore force_encrypted=false
old = '    lua_pushboolean(g_L, 1); /* DEBUG: force encrypted */'
new = '    lua_pushboolean(g_L, 0);'
s = s.replace(old, new, 1)

# Remove debug set_error, restore g_errbuf clearing
old2 = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    set_error("wasm_load OK: first_byte=0x%02X raw_len=%zu input_len=%d", first_byte, raw_len, len);
    return ref;'''
new2 = '''    int ref = luaL_ref(g_L, LUA_REGISTRYINDEX);
    g_errbuf[0] = '\\0';
    return ref;'''
s = s.replace(old2, new2, 1)

open(p, 'w', encoding='utf-8').write(s)
print('restored wasm_entry.c')
