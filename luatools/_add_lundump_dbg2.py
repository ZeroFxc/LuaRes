p = r'E:\LuaRes\luasafe\lundump.c'
s = open(p, encoding='utf-8').read()
old = 'LClosure *luaU_undump1(lua_State *L, ZIO *Z, const char *name) {\n  LoadState S;'
new = 'LClosure *luaU_undump1(lua_State *L, ZIO *Z, const char *name) {\n  fprintf(stderr, "[LUNDUMP] undump1 called name=%s\\n", name); fflush(stderr);\n  LoadState S;'
if old in s:
    s = s.replace(old, new)
    open(p, 'w', encoding='utf-8').write(s)
    print('entry debug added')
else:
    print('NOT FOUND')
