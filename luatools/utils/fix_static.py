path = r'E:\LuaRes\luaclib\luac.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('static void *luac_alloc(size_t sz)', 'void *luac_alloc(size_t sz)')
content = content.replace('static char *luac_strdup(const char *s)', 'char *luac_strdup(const char *s)')
content = content.replace('static char *luac_strndup(const char *s, size_t len)', 'char *luac_strndup(const char *s, size_t len)')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('done')
