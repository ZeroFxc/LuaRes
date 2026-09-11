path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '    luac_Proto *sub_ud = (luac_Proto *)lua_touserdata(L, -1);\n    fprintf(stderr, "DBG as: sub_ud=%p\\n", (void*)sub_ud); fflush(stderr);\n    p->p[idx] = sub_ud;\n    p->sizep++;',
    '    luac_Proto *sub_ud = (luac_Proto *)lua_touserdata(L, -1);\n    fprintf(stderr, "DBG as: sub_ud=%p p->p=%p idx=%d sizep=%d\\n", (void*)sub_ud, (void*)p->p, idx, p->sizep); fflush(stderr);\n    p->p[idx] = sub_ud;\n    fprintf(stderr, "DBG as: assigned\\n"); fflush(stderr);\n    p->sizep++;\n    fprintf(stderr, "DBG as: sizep++\\n"); fflush(stderr);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
