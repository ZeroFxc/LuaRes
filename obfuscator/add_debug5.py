with open(r'E:\LuaRes\luaclib\luac.c', 'r', encoding='utf-8') as f:
    content = f.read()

# 在 LoadUpvalues 加日志
old1 = """static void LoadUpvalues(UndumpState *S, luac_Proto *f) {
    f->sizeupvalues = LoadInt(S);"""
new1 = """static void LoadUpvalues(UndumpState *S, luac_Proto *f) {
    f->sizeupvalues = LoadInt(S);
#if LUACLIB_DEBUG
    fprintf(stderr, "[luac] LoadUpvalues: n=%d pos=%zu\\n", f->sizeupvalues, S->pos);
#endif"""
content = content.replace(old1, new1, 1)

# 在 LoadProtos 加日志
old2 = """static void LoadProtos(UndumpState *S, luac_Proto *f) {
    f->sizep = LoadInt(S);"""
new2 = """static void LoadProtos(UndumpState *S, luac_Proto *f) {
    f->sizep = LoadInt(S);
#if LUACLIB_DEBUG
    fprintf(stderr, "[luac] LoadProtos: n=%d pos=%zu\\n", f->sizep, S->pos);
#endif"""
content = content.replace(old2, new2, 1)

# 在 LoadDebug 的 lineinfo 加日志
old3 = """    f->sizelineinfo = LoadInt(S);
    if (f->sizelineinfo > 0) {"""
new3 = """    f->sizelineinfo = LoadInt(S);
#if LUACLIB_DEBUG
    fprintf(stderr, "[luac] LoadDebug lineinfo: n=%d pos=%zu\\n", f->sizelineinfo, S->pos);
#endif
    if (f->sizelineinfo > 0) {"""
content = content.replace(old3, new3, 1)

with open(r'E:\LuaRes\luaclib\luac.c', 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
