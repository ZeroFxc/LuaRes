path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '    /* cleanup: leave only sub_ud on stack */\n    lua_replace(L, top + 1);\n    lua_settop(L, top + 1);',
    '    fprintf(stderr, "DBG: cleanup top=%d current_top=%d\\n", top, lua_gettop(L)); fflush(stderr);\n    /* cleanup: leave only sub_ud on stack */\n    lua_replace(L, top + 1);\n    fprintf(stderr, "DBG: after replace top=%d\\n", lua_gettop(L)); fflush(stderr);\n    lua_settop(L, top + 1);\n    fprintf(stderr, "DBG: after settop top=%d\\n", lua_gettop(L)); fflush(stderr);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
