p = r'E:\LuaRes\luaclib\vm_asm\vm_embed.c'
s = open(p, encoding='utf-8').read()

# Replace fprintf with file write in vm_embed_generate
old = '''    fprintf(stderr, "[vm_embed debug] bc[0]=0x%02X encrypted=%d bc_len=%zu\\n", bc[0], r.encrypted, bc_len);'''
new = '''    { FILE *df = fopen("E:/LuaRes/luatools/_vm_embed_dbg.txt", "w"); fprintf(df, "bc[0]=0x%02X encrypted=%d bc_len=%zu\\n", bc[0], r.encrypted, bc_len); fclose(df); }'''
s = s.replace(old, new, 1)

# Replace fprintf in rd_string with file append
old2 = '''            fprintf(stderr, "[rd_string debug] len=%zu raw[0]=%d decrypted[0]=%d valid=%d\\n", len, raw[0], tmp[0], valid);'''
new2 = '''            { FILE *df = fopen("E:/LuaRes/luatools/_vm_embed_dbg.txt", "a"); fprintf(df, "rd_string len=%zu raw[0]=%d dec[0]=%d valid=%d\\n", len, raw[0], tmp[0], valid); fclose(df); }'''
s = s.replace(old2, new2, 1)

open(p, 'w', encoding='utf-8').write(s)
print('debug updated')
