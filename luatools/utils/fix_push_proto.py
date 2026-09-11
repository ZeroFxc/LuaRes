path = r'E:\LuaRes\luaclib\luac.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Make push_proto non-static
content = content.replace(
    'static void push_proto(lua_State *L, luac_Proto *f) {',
    'void luac_push_proto(lua_State *L, luac_Proto *f) {'
)
# Also fix the forward declaration
content = content.replace(
    'static void push_proto(lua_State *L, luac_Proto *f);',
    'void luac_push_proto(lua_State *L, luac_Proto *f);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
