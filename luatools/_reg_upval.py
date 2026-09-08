p = r'E:\LuaRes\luaclib\obf_register.c'
s = open(p, encoding='utf-8').read()
s = s.replace('int call_rewrite_process(lua_State *L);',
              'int call_rewrite_process(lua_State *L);\nint upvalue_promote_process(lua_State *L);')
s = s.replace('    {"call_rewrite_c", call_rewrite_process},',
              '    {"call_rewrite_c", call_rewrite_process},\n    {"upvalue_promote_c", upvalue_promote_process},')
open(p, 'w', encoding='utf-8').write(s)

p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()
s = s.replace('    "call_rewrite_c";',
              '    "call_rewrite_c,"\n    "upvalue_promote_c";')
open(p, 'w', encoding='utf-8').write(s)

p = r'E:\LuaRes\web\app.js'
s = open(p, encoding='utf-8').read()
s = s.replace(
    "{ id: 'call_rewrite_c', label: '参数/返回值混淆', desc: 'f(a,b)→f({a,b})内部解包，多返回值先打包再解包' },",
    "{ id: 'call_rewrite_c', label: '参数/返回值混淆', desc: 'f(a,b)→f({a,b})内部解包，多返回值先打包再解包' },\n    { id: 'upvalue_promote_c', label: 'upvalue升降', desc: 'IIFE包装把局部变量提升为upvalue，改变变量存储方式' },"
)
s = s.replace(
    "'call_rewrite_c',\n  'num_obfuscate_c'",
    "'call_rewrite_c','upvalue_promote_c',\n  'num_obfuscate_c'"
)
open(p, 'w', encoding='utf-8').write(s)
print('all registered')
