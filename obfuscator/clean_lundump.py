with open(r'E:\LuaRes\luasafe\lundump.c', 'r', encoding='utf-8') as f:
    content = f.read()

# 移除 LoadBlock 中的 fprintf
old1 = """static void LoadBlock (LoadState *S, void *b, size_t size) {
  if (luaZ_read(S->Z, b, size) != 0) {
    fprintf(stderr, "[lundump] TRUNCATED at pos=%zu, tried to read %zu bytes\\n", S->pos, size);
    error(S, "truncated");
  }
  S->pos += size;
}"""
new1 = """static void LoadBlock (LoadState *S, void *b, size_t size) {
  if (luaZ_read(S->Z, b, size) != 0)
    error(S, "truncated");
}"""
content = content.replace(old1, new1, 1)

# 移除 LoadFunction 中的 func_start 和 fprintf
old2 = """static int g_lundump_func_idx = 0;
static void LoadFunction (LoadState *S, Proto *f, TString *psource) {
  size_t func_start = S->pos;
  f->source = LoadString(S);"""
new2 = """static void LoadFunction (LoadState *S, Proto *f, TString *psource) {
  f->source = LoadString(S);"""
content = content.replace(old2, new2, 1)

# 移除 LoadFunction 末尾的 fprintf
old3 = """  LoadProtos(S, f);
  LoadDebug(S, f);
  if (func_start >= 0 && func_start <= 200000) {
    fprintf(stderr, "[lundump] func#%d start=%zu end=%zu size=%zu line=%d-%d np=%d ms=%d sc=%d sk=%d sp=%d\\n",
      g_lundump_func_idx, func_start, S->pos, S->pos-func_start,
      f->linedefined, f->lastlinedefined, f->numparams, f->maxstacksize,
      f->sizecode, f->sizek, f->sizep);
  }
  g_lundump_func_idx++;
}"""
new3 = """  LoadProtos(S, f);
  LoadDebug(S, f);
}"""
content = content.replace(old3, new3, 1)

# 移除 undump1/undump2 中的 S.pos = 0
old4 = """  S.L = L;
  S.Z = Z;
  S.encrypted = 0;
  S.pos = 0;
  checkHeader(&S);"""
new4 = """  S.L = L;
  S.Z = Z;
  S.encrypted = 0;
  checkHeader(&S);"""
content = content.replace(old4, new4, 1)

old5 = """  S.L = L;
  S.Z = Z;
  S.encrypted = 1;
  S.pos = 0;
  checkHeader(&S);"""
new5 = """  S.L = L;
  S.Z = Z;
  S.encrypted = 1;
  checkHeader(&S);"""
content = content.replace(old5, new5, 1)

# 移除 LoadState 中的 pos 字段
old6 = """  int encrypted;  /* 1 = andlua encrypted format (luaU_undump2) */
  size_t pos;  /* debug: track read position */
} LoadState;"""
new6 = """  int encrypted;  /* 1 = andlua encrypted format (luaU_undump2) */
} LoadState;"""
content = content.replace(old6, new6, 1)

# 移除 stdio.h（如果没有其他地方用）
# 保留 stdio.h，因为可能其他地方用

with open(r'E:\LuaRes\luasafe\lundump.c', 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
