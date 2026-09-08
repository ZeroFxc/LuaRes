p = r'E:\LuaRes\luaclib\const_hide.c'
s = open(p, encoding='utf-8').read()
old = '''static int process_function(lua_State *L, luac_Proto *p) {
    if (!p->k_str || p->sizek < 2) return 0;'''
new = '''static int process_function(lua_State *L, luac_Proto *p) {
    if (!p->k_str || p->sizek < 2) return 0;
    /* require _ENV as first upvalue for inline string.sub call */
    if (p->sizeupvalues < 1 || !p->upval_name || p->upval_name_len[0] != 3 ||
        memcmp(p->upval_name[0], "_ENV", 3) != 0) return 0;'''
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
