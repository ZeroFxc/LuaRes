with open(r'E:\LuaRes\luaclib\luac.c', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复1: push_proto 中 source NULL 时 push nil
old1 = """    if (strcmp(key, "source") == 0) { lua_pushstring(L, f->source ? f->source : ""); return 1; }"""
new1 = """    if (strcmp(key, "source") == 0) {
        if (f->source) lua_pushstring(L, f->source);
        else lua_pushnil(L);
        return 1;
    }"""
content = content.replace(old1, new1, 1)

# 修复2: sync 中 source nil 时设为 NULL
old2 = """    if (strcmp(key, "source") == 0) {
        free(f->source);
        f->source = luac_strdup(luaL_checkstring(L, 3));
        return 0;
    }"""
new2 = """    if (strcmp(key, "source") == 0) {
        free(f->source);
        if (lua_isnil(L, 3)) {
            f->source = NULL;
        } else {
            f->source = luac_strdup(luaL_checkstring(L, 3));
        }
        return 0;
    }"""
content = content.replace(old2, new2, 1)

with open(r'E:\LuaRes\luaclib\luac.c', 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
