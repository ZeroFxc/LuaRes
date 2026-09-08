p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Change function signature to include L
s = s.replace('static int promote_in_proto(luac_Proto *p, int count) {',
              'static int promote_in_proto(lua_State *L, luac_Proto *p, int count) {')

# Fix the call sites
s = s.replace('n += promote_in_proto(p->p[i], count>3?count/2:3);',
              'n += promote_in_proto(L, p->p[i], count>3?count/2:3);')
s = s.replace('n += promote_in_proto(p, count);',
              'n += promote_in_proto(L, p, count);')

open(p, 'w', encoding='utf-8').write(s)
print('added L parameter')
