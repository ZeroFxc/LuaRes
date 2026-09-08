p = r'E:\LuaRes\luaclib\vm_asm\vm_embed.c'
s = open(p, encoding='utf-8').read()

# Use relative path
s = s.replace('"E:/LuaRes/luatools/_vm_embed_dbg.txt"', '"_vm_dbg.txt"')

open(p, 'w', encoding='utf-8').write(s)
print('path updated')

# Also add debug at vm_embed_process entry in vm_embed_api.c
p2 = r'E:\LuaRes\luaclib\vm_embed_api.c'
s2 = open(p2, encoding='utf-8').read()
old = '''int vm_embed_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);'''
new = '''int vm_embed_process(lua_State *L) {
    { FILE *df = fopen("_vm_dbg.txt", "w"); fprintf(df, "vm_embed_process called\\n"); fclose(df); }
    luac_Proto *p = obf_check_proto(L);'''
s2 = s2.replace(old, new, 1)
open(p2, 'w', encoding='utf-8').write(s2)
print('api debug added')
