path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

old = '''int obf_add_subproto(lua_State *L, luac_Proto *p, luac_Proto *sub_raw) {
    int idx = p->sizep;
    p->p = realloc(p->p, sizeof(luac_Proto *) * (p->sizep + 1));

    luac_push_proto(L, sub_raw);
    luac_Proto *sub_ud = (luac_Proto *)lua_touserdata(L, -1);
    p->p[idx] = sub_ud;
    p->sizep++;

    if (p->p_tbl != LUA_NOREF) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, p->p_tbl);
        lua_pushvalue(L, -2);
        lua_rawseti(L, -2, idx + 1);
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
    return idx;
}'''

new = '''int obf_add_subproto(lua_State *L, luac_Proto *p, luac_Proto *sub_raw) {
    int idx = p->sizep;
    p->p = realloc(p->p, sizeof(luac_Proto *) * (p->sizep + 1));

    /* If p table doesn't exist yet, create it and populate with all existing
       sub-protos. This ensures all sub-proto userdata are referenced by Lua
       and won't be GC'd, preventing dangling pointers in p->p[]. */
    if (p->p_tbl == LUA_NOREF) {
        lua_newtable(L);
        for (int i = 0; i < idx; i++) {
            luac_push_proto(L, p->p[i]);
            luac_Proto *ud = (luac_Proto *)lua_touserdata(L, -1);
            p->p[i] = ud;
            lua_rawseti(L, -2, i + 1);
        }
        p->p_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    luac_push_proto(L, sub_raw);
    luac_Proto *sub_ud = (luac_Proto *)lua_touserdata(L, -1);
    p->p[idx] = sub_ud;
    p->sizep++;

    lua_rawgeti(L, LUA_REGISTRYINDEX, p->p_tbl);
    lua_pushvalue(L, -2);
    lua_rawseti(L, -2, idx + 1);
    lua_pop(L, 1);
    lua_pop(L, 1);
    return idx;
}'''

src = src.replace(old, new)
with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
print("obf_add_subproto fixed")
