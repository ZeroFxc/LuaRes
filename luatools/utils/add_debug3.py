path = r'E:\LuaRes\luaclib\str_encrypt.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '    obf_srand((unsigned int)time(NULL));\n\n    int count = 0;',
    '    obf_srand((unsigned int)time(NULL));\n    fprintf(stderr, "DBG: srand done\\n"); fflush(stderr);\n\n    int count = 0;'
)

content = content.replace(
    '    while (sp > 0) {\n        luac_Proto *cur = stack[--sp];',
    '    while (sp > 0) {\n        luac_Proto *cur = stack[--sp];\n        fprintf(stderr, "DBG: processing cur=%p sizecode=%d\\n", (void*)cur, cur->sizecode); fflush(stderr);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
