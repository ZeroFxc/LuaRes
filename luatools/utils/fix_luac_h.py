path = r'E:\LuaRes\luaclib\luac.h'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old = '''/* Proto lifecycle (defined in luac.c) */
luac_Proto *luac_new_proto(void);
luac_Proto *luac_check_proto(lua_State *L, int idx);
int luac_push_proto(lua_State *L, luac_Proto *p);

/* undump / dump */
luac_Proto *luac_undump_data(const char *data, size_t len, int force_encrypted);
char *luac_dump_data(luac_Proto *p, size_t *out_len);'''

new = '''/* Proto lifecycle (defined in luac.c) */
luac_Proto *luac_new_proto(void);
luac_Proto *luac_check_proto(lua_State *L, int idx);
void luac_push_proto(lua_State *L, luac_Proto *p);'''

if old in content:
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('done')
else:
    print('NOT FOUND')
