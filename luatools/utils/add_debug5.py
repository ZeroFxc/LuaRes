path = r'E:\LuaRes\luaclib\str_encrypt.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add debug after collecting string indices
content = content.replace(
    '    if (enc_count == 0) { fprintf(stderr, "DBG: no strings\\n"); return 0; }',
    '    fprintf(stderr, "DBG: enc_count=%d\\n", enc_count); fflush(stderr);\n    if (enc_count == 0) { fprintf(stderr, "DBG: no strings\\n"); return 0; }'
)

# Add debug after counting LOADK
content = content.replace(
    '    if (loadk_count == 0) { fprintf(stderr, "DBG: no loadk\\n"); return 0; }',
    '    fprintf(stderr, "DBG: loadk_count=%d\\n", loadk_count); fflush(stderr);\n    if (loadk_count == 0) { fprintf(stderr, "DBG: no loadk\\n"); return 0; }'
)

# Add debug before encrypting strings
content = content.replace(
    '    /* encrypt all string constants */',
    '    fprintf(stderr, "DBG: encrypting strings\\n"); fflush(stderr);\n    /* encrypt all string constants */'
)

# Add debug after encrypting
content = content.replace(
    '    fprintf(stderr, "DBG: creating decrypt proto\\n");',
    '    fprintf(stderr, "DBG: strings encrypted\\n"); fflush(stderr);\n    fprintf(stderr, "DBG: creating decrypt proto\\n");'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
