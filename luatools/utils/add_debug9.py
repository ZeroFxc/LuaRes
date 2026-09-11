path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '    lua_settop(L, top + 1);\n    fprintf(stderr, "DBG: after settop top=%d\\n", lua_gettop(L)); fflush(stderr);\n\n    return sub_ud;',
    '    lua_settop(L, top + 1);\n    fprintf(stderr, "DBG: after settop top=%d\\n", lua_gettop(L)); fflush(stderr);\n    fprintf(stderr, "DBG: sub_ud->maxstacksize=%d\\n", sub_ud->maxstacksize); fflush(stderr);\n    fprintf(stderr, "DBG: sub_ud->sizecode=%d\\n", sub_ud->sizecode); fflush(stderr);\n\n    return sub_ud;'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
