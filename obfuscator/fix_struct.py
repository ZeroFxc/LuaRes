with open(r'E:\LuaRes\luasafe\lundump.c', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复 LoadState 结构体 - 加 pos 字段
old1 = """typedef struct {
  lua_State *L;
  ZIO *Z;
  const char *name;
  size_t sizeof_size_t;
  int encrypted;  /* 1 = andlua encrypted format (luaU_undump2) */
} LoadState;"""

new1 = """typedef struct {
  lua_State *L;
  ZIO *Z;
  const char *name;
  size_t sizeof_size_t;
  int encrypted;  /* 1 = andlua encrypted format (luaU_undump2) */
  size_t pos;  /* debug: track read position */
} LoadState;"""

if old1 in content:
    content = content.replace(old1, new1, 1)
    print('struct fixed')
else:
    print('struct NOT FOUND')

with open(r'E:\LuaRes\luasafe\lundump.c', 'w', encoding='utf-8') as f:
    f.write(content)
