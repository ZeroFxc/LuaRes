p = r'E:\LuaRes\luaclib\obf_util.c'
s = open(p, encoding='utf-8').read()

old = '''int obf_compile_subproto(lua_State *L, const char *src, luac_Proto **out) {
    int top = lua_gettop(L);

    if (luaL_loadstring(L, src) != LUA_OK) { lua_settop(L, top); return 0; }

    lua_getglobal(L, "string");
    lua_getfield(L, -1, "dump");
    lua_pushvalue(L, -3);
    lua_call(L, 1, 1);

    lua_getglobal(L, "string");
    lua_getfield(L, -1, "dec");
    if (lua_isfunction(L, -1)) {
        lua_pushvalue(L, -3);
        lua_call(L, 1, 1);
        lua_replace(L, -3);
        lua_pop(L, 1);
    } else {
        lua_pop(L, 2);
    }

    lua_getglobal(L, "luac");
    lua_getfield(L, -1, "undump");
    lua_pushvalue(L, -3);
    lua_pushboolean(L, 0);
    lua_call(L, 2, 1);

    luac_Proto *main_p = (luac_Proto *)luaL_checkudata(L, -1, "luac.Proto");
    luac_Proto *sub_raw = NULL;
    if (main_p->p && main_p->sizep >= 1) sub_raw = main_p->p[0];
    if (!sub_raw) { lua_settop(L, top); return 0; }'''

new = '''int obf_compile_subproto(lua_State *L, const char *src, luac_Proto **out) {
    int top = lua_gettop(L);
    fprintf(stderr,"[OCS] start src=%s top=%d\\n",src,top);

    if (luaL_loadstring(L, src) != LUA_OK) {
        fprintf(stderr,"[OCS] loadstring FAILED: %s\\n",lua_tostring(L,-1));
        lua_settop(L, top); return 0;
    }
    fprintf(stderr,"[OCS] loadstring OK\\n");

    lua_getglobal(L, "string");
    lua_getfield(L, -1, "dump");
    if(!lua_isfunction(L,-1)){fprintf(stderr,"[OCS] string.dump NOT function\\n");lua_settop(L,top);return 0;}
    lua_pushvalue(L, -3);
    lua_call(L, 1, 1);
    fprintf(stderr,"[OCS] dump OK type=%d\\n",lua_type(L,-1));

    lua_getglobal(L, "string");
    lua_getfield(L, -1, "dec");
    if (lua_isfunction(L, -1)) {
        fprintf(stderr,"[OCS] string.dec found\\n");
        lua_pushvalue(L, -3);
        lua_call(L, 1, 1);
        lua_replace(L, -3);
        lua_pop(L, 1);
    } else {
        fprintf(stderr,"[OCS] string.dec NOT found (skip)\\n");
        lua_pop(L, 2);
    }

    lua_getglobal(L, "luac");
    if(!lua_istable(L,-1)){fprintf(stderr,"[OCS] luac NOT table\\n");lua_settop(L,top);return 0;}
    lua_getfield(L, -1, "undump");
    if(!lua_isfunction(L,-1)){fprintf(stderr,"[OCS] luac.undump NOT function\\n");lua_settop(L,top);return 0;}
    lua_pushvalue(L, -3);
    lua_pushboolean(L, 0);
    lua_call(L, 2, 1);
    fprintf(stderr,"[OCS] undump OK type=%d\\n",lua_type(L,-1));

    luac_Proto *main_p = (luac_Proto *)luaL_checkudata(L, -1, "luac.Proto");
    fprintf(stderr,"[OCS] main_p sizecode=%d sizep=%d\\n",main_p->sizecode,main_p->sizep);
    luac_Proto *sub_raw = NULL;
    if (main_p->p && main_p->sizep >= 1) sub_raw = main_p->p[0];
    if (!sub_raw) { fprintf(stderr,"[OCS] no sub_proto sizep=%d\\n",main_p->sizep); lua_settop(L, top); return 0; }'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('added debug to obf_compile_subproto')
