p = r'E:\LuaRes\luaclib\luac.c'
s = open(p, encoding='utf-8').read()

# Force always decrypt when encrypted, and add debug to g_errbuf via a global
old = '''#if LUACLIB_AUTO_DECRYPT
    /* andlua: only decrypt strings when bytecode is in encrypted format */
    if (S->encrypted && len > 0) {
        unsigned char *tmp = luac_alloc(len);
        memcpy(tmp, s, len);
        andlua_decrypt_string(tmp, len);
        int valid = (len == 1) || andlua_is_valid_text(tmp, len);'''

new = '''#if LUACLIB_AUTO_DECRYPT
    /* andlua: only decrypt strings when bytecode is in encrypted format */
    if (S->encrypted && len > 0) {
        unsigned char *tmp = luac_alloc(len);
        memcpy(tmp, s, len);
        andlua_decrypt_string(tmp, len);
        int valid = 1; /* DEBUG FORCE: always decrypt when encrypted */'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('force always decrypt')
