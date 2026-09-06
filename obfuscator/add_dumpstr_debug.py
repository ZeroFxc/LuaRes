with open(r'E:\LuaRes\luaclib\luac.c', 'r', encoding='utf-8') as f:
    content = f.read()

old = """static void DumpString(DumpState *D, const char *s) {
    if (!s) {
        DumpByte(D, 0);
        return;
    }
    size_t len = strlen(s);"""

new = """static int g_dump_empty_str = 0;
static void DumpString(DumpState *D, const char *s) {
    if (!s) {
        DumpByte(D, 0);
        return;
    }
    size_t len = strlen(s);
    if (len == 0) {
        g_dump_empty_str++;
        if (g_dump_empty_str <= 5) fprintf(stderr, "[DumpString] empty string at pos=%zu\\n", D->pos);
    }"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luaclib\luac.c', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
