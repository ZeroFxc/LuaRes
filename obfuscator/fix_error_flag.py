with open(r'E:\LuaRes\luaclib\luac.c', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. UndumpState 加 error 字段
old1 = """} UndumpState;"""
new1 = """    int error;  /* set when read goes past end of buffer */
} UndumpState;"""
content = content.replace(old1, new1, 1)

# 2. LoadByte 越界时设置 error
old2 = """static unsigned char LoadByte(UndumpState *S) {
    if (S->pos >= S->len) {
        /* tolerate: packers may corrupt sizecode; zero-fill and advance virtual pos
           so subsequent reads don't get stuck at the same offset */
        S->pos++;
        return 0;
    }
    return S->buf[S->pos++];
}"""
new2 = """static unsigned char LoadByte(UndumpState *S) {
    if (S->pos >= S->len) {
        S->error = 1;
        S->pos++;
        return 0;
    }
    return S->buf[S->pos++];
}"""
content = content.replace(old2, new2, 1)

# 3. LoadFunction 开头检查 error
old3 = """static int g_func_idx = 0;
static void LoadFunction(UndumpState *S, luac_Proto *f) {
    size_t func_start = S->pos;
    f->source = LoadString(S);"""
new3 = """static int g_func_idx = 0;
static void LoadFunction(UndumpState *S, luac_Proto *f) {
    size_t func_start = S->pos;
    if (S->error) {
        f->sizecode = 0; f->sizek = 0; f->sizep = 0;
        f->sizeupvalues = 0; f->sizelineinfo = 0; f->sizelocvars = 0;
        return;
    }
    f->source = LoadString(S);"""
content = content.replace(old3, new3, 1)

# 4. luac_undump 中初始化 error=0
old4 = """    S.buf = (const unsigned char *)data;
    S.pos = 0;
    S.len = len;
    S.encrypted = 0;"""
new4 = """    S.buf = (const unsigned char *)data;
    S.pos = 0;
    S.len = len;
    S.encrypted = 0;
    S.error = 0;"""
content = content.replace(old4, new4, 1)

with open(r'E:\LuaRes\luaclib\luac.c', 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
