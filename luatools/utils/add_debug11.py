path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'int obf_add_subproto(lua_State *L, luac_Proto *p, luac_Proto *sub_raw) {\n    int idx = p->sizep;',
    'int obf_add_subproto(lua_State *L, luac_Proto *p, luac_Proto *sub_raw) {\n    fprintf(stderr, "DBG as: entry p=%p sub=%p\\n", (void*)p, (void*)sub_raw); fflush(stderr);\n    int idx = p->sizep;'
)

content = content.replace(
    '    /* create userdata for sub-proto (takes ownership of arrays) */\n    luac_push_proto(L, sub_raw);',
    '    fprintf(stderr, "DBG as: push_proto\\n"); fflush(stderr);\n    /* create userdata for sub-proto (takes ownership of arrays) */\n    luac_push_proto(L, sub_raw);'
)

content = content.replace(
    '    luac_Proto *sub_ud = (luac_Proto *)lua_touserdata(L, -1);\n    p->p[idx] = sub_ud;',
    '    luac_Proto *sub_ud = (luac_Proto *)lua_touserdata(L, -1);\n    fprintf(stderr, "DBG as: sub_ud=%p\\n", (void*)sub_ud); fflush(stderr);\n    p->p[idx] = sub_ud;'
)

content = content.replace(
    '    lua_pop(L, 1); /* pop sub_ud */\n    return idx;',
    '    fprintf(stderr, "DBG as: done idx=%d\\n", idx); fflush(stderr);\n    lua_pop(L, 1); /* pop sub_ud */\n    return idx;'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
