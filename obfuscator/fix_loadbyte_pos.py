with open(r'E:\LuaRes\luaclib\luac.c', 'r', encoding='utf-8') as f:
    content = f.read()

old = """static unsigned char LoadByte(UndumpState *S) {
    if (S->pos >= S->len) {
        /* tolerate: packers may corrupt sizecode; zero-fill remainder */
        return 0;
    }
    return S->buf[S->pos++];
}"""

new = """static unsigned char LoadByte(UndumpState *S) {
    if (S->pos >= S->len) {
        /* tolerate: packers may corrupt sizecode; zero-fill and advance virtual pos
           so subsequent reads don't get stuck at the same offset */
        S->pos++;
        return 0;
    }
    return S->buf[S->pos++];
}"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luaclib\luac.c', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
