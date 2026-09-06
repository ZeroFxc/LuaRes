path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '    fprintf(stderr, "DBG as: sizep++\\n"); fflush(stderr);',
    '    fprintf(stderr, "DBG as: sizep++ p_tbl=%d code_tbl=%d k_tbl=%d\\n", p->p_tbl, p->code_tbl, p->k_tbl); fflush(stderr);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
