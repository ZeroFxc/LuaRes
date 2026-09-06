path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove lua_settop from obf_compile_subproto - just return
content = content.replace(
    '    /* cleanup stack */\n    lua_settop(L, top);\n\n    return sub_raw;',
    '    /* NO stack cleanup - caller must handle */\n    fprintf(stderr, "DBG: sub_raw->maxstack=%d before return\\n", sub_raw->maxstacksize); fflush(stderr);\n    return sub_raw;'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
