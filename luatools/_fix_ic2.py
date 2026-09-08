p = r'E:\LuaRes\luaclib\integrity_check.c'
s = open(p, encoding='utf-8').read()

old = '#include "luac.h"'
new = '''#include "luac.h"

/* 外部函数声明 */
int luaopen_luac(lua_State *L);'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('done')
