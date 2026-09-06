with open(r'E:\LuaRes\luaclib\luac.c', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. create_upvalues_table: NULL name -> push nil
old1 = """        lua_pushstring(L, f->upval_name[i] ? f->upval_name[i] : "");
        lua_setfield(L, -2, "name");"""
new1 = """        if (f->upval_name[i]) lua_pushstring(L, f->upval_name[i]);
        else lua_pushnil(L);
        lua_setfield(L, -2, "name");"""
content = content.replace(old1, new1, 1)

# 2. sync_upvalues_from_table: nil name -> NULL
old2 = """            lua_getfield(L, -1, "name");
            f->upval_name[i] = luac_strdup(lua_tostring(L, -1));
            lua_pop(L, 1);
            lua_getfield(L, -1, "instack");"""
new2 = """            lua_getfield(L, -1, "name");
            if (lua_isnil(L, -1)) f->upval_name[i] = NULL;
            else f->upval_name[i] = luac_strdup(lua_tostring(L, -1));
            lua_pop(L, 1);
            lua_getfield(L, -1, "instack");"""
content = content.replace(old2, new2, 1)

# 3. create_locvars_table: NULL varname -> push nil
old3 = """        lua_pushstring(L, f->locvar_name[i] ? f->locvar_name[i] : "");
        lua_setfield(L, -2, "varname");"""
new3 = """        if (f->locvar_name[i]) lua_pushstring(L, f->locvar_name[i]);
        else lua_pushnil(L);
        lua_setfield(L, -2, "varname");"""
content = content.replace(old3, new3, 1)

# 4. sync_locvars_from_table: nil varname -> NULL
old4 = """            lua_getfield(L, -1, "varname");
            f->locvar_name[i] = luac_strdup(lua_tostring(L, -1));
            lua_pop(L, 1);
            lua_getfield(L, -1, "startpc");"""
new4 = """            lua_getfield(L, -1, "varname");
            if (lua_isnil(L, -1)) f->locvar_name[i] = NULL;
            else f->locvar_name[i] = luac_strdup(lua_tostring(L, -1));
            lua_pop(L, 1);
            lua_getfield(L, -1, "startpc");"""
content = content.replace(old4, new4, 1)

with open(r'E:\LuaRes\luaclib\luac.c', 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
