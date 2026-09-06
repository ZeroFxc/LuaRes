with open(r'E:\LuaRes\luasafe\lundump.c', 'r', encoding='utf-8') as f:
    content = f.read()

# 在 LoadState 结构体中加 pos 字段
old1 = """typedef struct {
  lua_State *L;
  ZIO *Z;
  const char *name;
  int encrypted;  /* andlua: whether strings are encrypted */
  int sizeof_size_t;  /* andlua: need this for LoadString long format */
} LoadState;"""

new1 = """typedef struct {
  lua_State *L;
  ZIO *Z;
  const char *name;
  int encrypted;  /* andlua: whether strings are encrypted */
  int sizeof_size_t;  /* andlua: need this for LoadString long format */
  size_t pos;  /* debug: track read position */
} LoadState;"""

if old1 in content:
    content = content.replace(old1, new1, 1)
else:
    print('LoadState struct not found, searching...')
    # 尝试找到结构体定义

# 在 LoadBlock 中更新 pos 并加日志
old2 = """static void LoadBlock (LoadState *S, void *b, size_t size) {
  if (luaZ_read(S->Z, b, size) != 0)
    error(S, "truncated");
}"""

new2 = """static void LoadBlock (LoadState *S, void *b, size_t size) {
  if (luaZ_read(S->Z, b, size) != 0) {
    fprintf(stderr, "[lundump] TRUNCATED at pos=%zu, tried to read %zu bytes\\n", S->pos, size);
    error(S, "truncated");
  }
  S->pos += size;
}"""

content = content.replace(old2, new2, 1)

# 在 LoadFunction 开头加日志
old3 = """static void LoadFunction (LoadState *S, Proto *f, TString *psource) {
  f->source = LoadString(S);"""

new3 = """static int g_lundump_func_idx = 0;
static void LoadFunction (LoadState *S, Proto *f, TString *psource) {
  size_t func_start = S->pos;
  f->source = LoadString(S);"""

content = content.replace(old3, new3, 1)

# 在 LoadFunction 末尾加日志（在 LoadDebug 之后）
old4 = """  LoadProtos(S, f);
  LoadDebug(S, f);
}"""

new4 = """  LoadProtos(S, f);
  LoadDebug(S, f);
  if (func_start >= 0 && func_start <= 200000) {
    fprintf(stderr, "[lundump] func#%d start=%zu end=%zu size=%zu line=%d-%d np=%d ms=%d sc=%d sk=%d sp=%d\\n",
      g_lundump_func_idx, func_start, S->pos, S->pos-func_start,
      f->linedefined, f->lastlinedefined, f->numparams, f->maxstacksize,
      f->sizecode, f->sizek, f->sizep);
  }
  g_lundump_func_idx++;
}"""

content = content.replace(old4, new4, 1)

# 在 undump1/undump2 中初始化 pos=0
old5 = """  S.L = L;
  S.Z = Z;
  S.encrypted = 0;
  checkHeader(&S);"""

new5 = """  S.L = L;
  S.Z = Z;
  S.encrypted = 0;
  S.pos = 0;
  checkHeader(&S);"""

content = content.replace(old5, new5, 1)

old6 = """  S.L = L;
  S.Z = Z;
  S.encrypted = 1;
  checkHeader(&S);"""

new6 = """  S.L = L;
  S.Z = Z;
  S.encrypted = 1;
  S.pos = 0;
  checkHeader(&S);"""

content = content.replace(old6, new6, 1)

with open(r'E:\LuaRes\luasafe\lundump.c', 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
