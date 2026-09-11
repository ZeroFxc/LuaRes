path = r'E:\LuaRes\luaclib\str_encrypt.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add fflush after the first debug print in encrypt_function
content = content.replace(
    '    fprintf(stderr, "DBG: encrypt_function start, sizecode=%d sizek=%d\\n", p->sizecode, p->sizek);',
    '    fprintf(stderr, "DBG: encrypt_function start, sizecode=%d sizek=%d\\n", p->sizecode, p->sizek); fflush(stderr);'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
