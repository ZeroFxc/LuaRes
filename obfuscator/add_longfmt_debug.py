with open(r'E:\LuaRes\luaclib\luac.c', 'r', encoding='utf-8') as f:
    content = f.read()

# 在 LoadString 中加统计
old = """static char *LoadString(UndumpState *S) {
    size_t size = LoadByte(S);
    if (size == 0xFF) {
        size = 0;
        for (int i = 0; i < 4; i++) size |= ((size_t)LoadByte(S)) << (i * 8);
    }"""

new = """static int g_longfmt_short = 0;  /* count strings using 0xFF format but size <= 253 */
static char *LoadString(UndumpState *S) {
    size_t size = LoadByte(S);
    int used_longfmt = (size == 0xFF);
    if (size == 0xFF) {
        size = 0;
        for (int i = 0; i < 4; i++) size |= ((size_t)LoadByte(S)) << (i * 8);
    }
    if (used_longfmt && size <= 253) g_longfmt_short++;"""

if old in content:
    content = content.replace(old, new, 1)
    # 在 undump done 日志中加统计
    old2 = """#if LUACLIB_DEBUG
    fprintf(stderr, "[luac] undump done: parsed=%zu total=%zu tail=%zu\\n", S.pos, S.len, S.len - S.pos);
#endif"""
    new2 = """#if LUACLIB_DEBUG
    fprintf(stderr, "[luac] undump done: parsed=%zu total=%zu tail=%zu longfmt_short=%d\\n", S.pos, S.len, S.len - S.pos, g_longfmt_short);
#endif"""
    content = content.replace(old2, new2, 1)
    with open(r'E:\LuaRes\luaclib\luac.c', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
