path = r'E:\LuaRes\luaclib\obf_util.h'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'luac_Proto *obf_compile_subproto(lua_State *L, const char *src);',
    'int obf_compile_subproto(lua_State *L, const char *src, luac_Proto **out);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('header done')

path2 = r'E:\LuaRes\luaclib\obf_util.c'
with open(path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

# Replace function signature and return
content2 = content2.replace(
    'luac_Proto *obf_compile_subproto(lua_State *L, const char *src) {',
    'int obf_compile_subproto(lua_State *L, const char *src, luac_Proto **out) {'
)

# Replace all return NULL with return 0
# Replace the final return sub_raw with *out = sub_raw; return 1
content2 = content2.replace(
    '        lua_settop(L, top);\n        return NULL;\n    }\n\n    /* fix upvalue */',
    '        lua_settop(L, top);\n        return 0;\n    }\n\n    /* fix upvalue */'
)

# There might be another return NULL at the beginning
content2 = content2.replace(
    '    if (luaL_loadstring(L, src) != LUA_OK) {\n        lua_settop(L, top);\n        return NULL;\n    }',
    '    if (luaL_loadstring(L, src) != LUA_OK) {\n        lua_settop(L, top);\n        return 0;\n    }'
)

# Replace the final return
content2 = content2.replace(
    '    /* NO stack cleanup - caller must handle */\n    fprintf(stderr, "DBG: sub_raw->maxstack=%d before return\\n", sub_raw->maxstacksize); fflush(stderr);\n    return sub_raw;',
    '    lua_settop(L, top);\n    *out = sub_raw;\n    return 1;'
)

with open(path2, 'w', encoding='utf-8') as f:
    f.write(content2)
print('source done')
