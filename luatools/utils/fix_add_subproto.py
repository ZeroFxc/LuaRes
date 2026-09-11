path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace obf_add_subproto
old_start = content.find('int obf_add_subproto(')
old_end = content.find('\n/*=====', old_start + 10)
old_func = content[old_start:old_end]

new_func = '''int obf_add_subproto(lua_State *L, luac_Proto *p, luac_Proto *sub_raw) {
    int idx = p->sizep;
    p->p = realloc(p->p, sizeof(luac_Proto *) * (p->sizep + 1));

    /* create userdata for sub-proto (takes ownership of arrays) */
    luac_push_proto(L, sub_raw);
    luac_Proto *sub_ud = (luac_Proto *)lua_touserdata(L, -1);
    p->p[idx] = sub_ud;
    p->sizep++;

    /* store userdata in parent's p Lua table for GC reference */
    if (p->p_tbl != 0) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, p->p_tbl);
        lua_pushvalue(L, -2); /* sub_ud */
        lua_rawseti(L, -2, idx + 1);
        lua_pop(L, 1); /* p table */
    }

    lua_pop(L, 1); /* pop sub_ud */
    return idx;
}
'''

content = content[:old_start] + new_func + content[old_end:]

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
