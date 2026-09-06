path = r'E:\LuaRes\luaclib\const_shuffle.c'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

old = '''int const_shuffle_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    fprintf(stderr, "[cs] got proto sizek=%d sizecode=%d sizep=%d\\n", p->sizek, p->sizecode, p->sizep);'''

new = '''int const_shuffle_process(lua_State *L) {
    fprintf(stderr, "[cs] ENTER\\n"); fflush(stderr);
    luac_Proto *p = obf_check_proto(L);
    fprintf(stderr, "[cs] got proto sizek=%d sizecode=%d sizep=%d\\n", p->sizek, p->sizecode, p->sizep); fflush(stderr);'''

src = src.replace(old, new)
with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
print("debug added at entry")
