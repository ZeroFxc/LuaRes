with open(r'E:\LuaRes\luaclib\luac.c', 'r', encoding='utf-8') as f:
    content = f.read()

old = """static void LoadFunction(UndumpState *S, luac_Proto *f) {
    f->source = LoadString(S);
    f->linedefined = LoadInt(S);
    f->lastlinedefined = LoadInt(S);
    f->numparams = LoadByte(S);
    f->is_vararg = LoadByte(S);
    f->maxstacksize = LoadByte(S);
#if LUACLIB_DEBUG
    fprintf(stderr, "[luac] LoadFunction: source='%s' line=%d-%d numparams=%d vararg=%d maxstack=%d\\n",
            f->source ? f->source : "(null)", f->linedefined, f->lastlinedefined,
            f->numparams, f->is_vararg, f->maxstacksize);
#endif"""

new = """static void LoadFunction(UndumpState *S, luac_Proto *f) {
    size_t func_start = S->pos;
    f->source = LoadString(S);
    f->linedefined = LoadInt(S);
    f->lastlinedefined = LoadInt(S);
    f->numparams = LoadByte(S);
    f->is_vararg = LoadByte(S);
    f->maxstacksize = LoadByte(S);
#if LUACLIB_DEBUG
    if (func_start >= 11200 && func_start <= 11400) {
        fprintf(stderr, "[luac] LoadFunction start=%zu source='%s' line=%d-%d np=%d va=%d ms=%d\\n",
                func_start, f->source ? f->source : "(null)", f->linedefined, f->lastlinedefined,
                f->numparams, f->is_vararg, f->maxstacksize);
    }
#endif"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luaclib\luac.c', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
